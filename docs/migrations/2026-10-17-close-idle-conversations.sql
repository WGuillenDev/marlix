-- Migration for S4-6: end idle conversations, which starts the memory extraction.
--
-- For a database created from docs/schema.sql before S4-6 (the Supabase
-- project of S4-1). A new database already gets this from docs/schema.sql.
-- Run it once in the Supabase SQL Editor, BEFORE deploying the backend that
-- calls it. It runs in a transaction: if anything fails, nothing changes.

begin;

-- Ends the conversations without activity for `p_idle_seconds` (S4-6), of one
-- user or of everybody, and returns their ids. A conversation ends at its last
-- message, not at the moment this runs, so `ended_at` says when it really
-- stopped. Only the backend calls it; ending a conversation is what starts the
-- memory extraction.
create function public.close_idle_conversations(
  p_idle_seconds integer,
  p_user_id uuid default null
)
returns setof uuid
language sql
set search_path = ''
as $$
  update public.conversations c
  set ended_at = last_activity.at
  from (
    select cv.id,
           greatest(cv.started_at, coalesce(max(m.created_at), cv.started_at)) as at
    from public.conversations cv
    left join public.messages m on m.conversation_id = cv.id
    where cv.ended_at is null
      and (p_user_id is null or cv.user_id = p_user_id)
    group by cv.id, cv.started_at
  ) last_activity
  where c.id = last_activity.id
    and last_activity.at < now() - make_interval(secs => p_idle_seconds)
  returning c.id;
$$;

-- Nobody but the backend can call it (S1-8).
revoke execute on function public.close_idle_conversations(integer, uuid)
  from public, anon, authenticated;
grant execute on function public.close_idle_conversations(integer, uuid) to service_role;

commit;
