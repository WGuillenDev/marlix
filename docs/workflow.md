# Workflow

How a v0.2 item goes from planning to Done. Use this repository and GitHub as the sources of truth for Marlix. Weekly sprints plan and review the work, a Kanban board tracks the state of each item, and changes reach `main` only through reviewed pull requests from `wil`. These rules come from section 10 of the [v0.2 design](designs/marlix-v0-2.md#10-marlix-v02-development-flow), approved on 2026-11-20 and updated on 2026-11-21 for branch `wil` and autonomous runs. Until C10, the owner's approval to adopt GitHub Issues and Projects for the v0.2 backlog, [`status.md`](../status.md) is the public summary of the board, and the maintainer keeps the operating detail (blockers, owner actions, sprint records) in private notes that are not in the repository.

**A** is the assistant ([Agent-assisted work](#agent-assisted-work)) and **O** is the owner.

## Branches: `main` and `wil`

*   **`main`** is the protected trunk. The "Protect main" ruleset allows only squash merges, requires the API, App and Database checks, and requires the branch to be up to date with `main`. Every change enters through a pull request with base `main`.
*   **`wil`** is the only shared working branch between the assistant and the owner. Every pull request of this workflow goes from `wil` to `main`. At any moment `wil` carries one implementation item and at most one open pull request.
*   **Before editing,** A checks `git status`, whether `wil` exists locally and on `origin`, `git rev-list --left-right --count origin/main...wil`, and `gh pr list --head wil`. Uncommitted or unpushed work is preserved. If the owner may be using `wil`, A asks first.
*   **An independent reviewer** (a pstack review subagent, or a person) reads the diff and reruns the checks from a read-only checkout or a detached worktree. It never commits to `wil` and never publishes another branch.
*   **Other branches** (Dependabot, older topic branches such as `docs/v0-2-status-layout`) are preserved. Dependabot pull requests keep their own branches and are reviewed as before. Retiring an older branch or pull request is a separate owner decision.
*   **Contributors from outside** keep using `<type>/<short-description>` branches, as `CONTRIBUTING.md` says.

### Preparing `wil` after a merge

A squash merge writes one new commit on `main`, so `wil` keeps the original commits and diverges from `main`. Before the next item:

1.  `git fetch --prune origin` and read the merged pull request's head: `gh pr view <n> --json headRefOid,mergeCommit`.
2.  **Check for pending work.** If `origin/wil` still equals that `headRefOid` and the local `wil` has no other commits (`git log <headRefOid>..wil` is empty) and `git status` is clean, nothing is pending. Otherwise stop: the extra commits are reported to the owner, and nothing is realigned.
3.  **Realign.** `git switch wil`, `git reset --hard origin/main`, then `git push --force-with-lease=wil:<headRefOid> origin wil`. The lease makes the push fail if anyone moved `wil` meanwhile. This rewrites the remote `wil`, so it needs the owner's explicit authorization.
4.  **If GitHub deleted the remote `wil`** (the repository setting "Automatically delete head branches" is on today), recreate it from `origin/main` with `git push -u origin wil` after the same check. This creates a remote branch, so it needs the same authorization. Turning that setting off keeps `wil` permanent and is the owner's decision.

While a pull request is open, `wil` is brought up to date with `main` by merging (`git merge origin/main`, or "Update branch" on GitHub). History that was already pushed is never rewritten while its pull request is open.

## Planning and reviews

Work is planned in weekly sprints. The owner chooses a verifiable Sprint Goal and the items that serve it, and reviews the result at the end of the week. Sprint records, estimates and retrospectives are kept in the maintainer's private notes; a pull request names its item and how it serves the current Sprint Goal.

## Board states

Until C10 the states are summarized in `status.md`; after C10 they live on the GitHub Projects board. The states are the same.

| State | An item is here when | It moves on when |
|---|---|---|
| **Backlog** | It is a V2-NN task of [the design](designs/marlix-v0-2.md#detailed-implementation-plan) (after C10, an issue) that is not yet ready. | It meets the [Definition of Ready](#definition-of-ready): scope, acceptance criteria and a way to verify them. |
| **Ready** | It meets the Definition of Ready and its dependencies are completed and verified. Order: priority, then number. | It is approved for the sprint, no other implementation item is in progress on `wil`, and the owner has authorized it. |
| **In Progress** | It is the one implementation item on `wil`, or the one paused task that is blocked. | Every acceptance criterion has evidence, the local checks pass, and a pull request from `wil` to `main` is open. |
| **In Review** | A pull request from `wil` to `main` exists, follows [the template](#pull-requests) with evidence, and shows the real CI state of its last pushed commit. | It is merged (by O, or by A when the run authorizes merging). If CI fails or O asks for changes, it goes back to In Progress. |
| **Done** | The pull request is merged and the [post-merge checks](#post-merge-checks) that apply have passed. | If a post-merge check fails, the item is reopened and returns to In Progress. |

**Blockers.** Any item can be blocked. Each blocker records the **cause**, **who acts** (owner, assistant or an outside party, by role), **what lets the work continue**, what it depends on, and the date (the full record is in [Blocked tasks and switching](#blocked-tasks-and-switching)). Blocker records stay in the maintainer's private notes; `status.md` shows only the item's public state.

**Done in short:** merged into `main` through a pull request from `wil`, CI of `main` green, and the post-merge checks that apply passed. A merged item whose post-merge check fails is not Done.

## The cycle before C10

The life of an item ([10.4](designs/marlix-v0-2.md#104-the-life-of-a-task)) without a board or issues.

1.  **Start the session (A).** Read the maintainer's private board (the session entry point; it is not in the repository), then run `git status` and `git log -5`, check the CI of `main`, and check `wil` as in [Branches](#branches-main-and-wil). If the board or `status.md` disagrees with `git log` and the merged pull requests, fix them.
2.  **Choose (A, within the owner's authorization).** Take the first Ready item approved for the current sprint. If an item is already in progress or paused, apply [Blocked tasks and switching](#blocked-tasks-and-switching).
3.  **Take it (A).** Move it to In Progress in `status.md` and re-read its entry in [the design](designs/marlix-v0-2.md#detailed-implementation-plan) against reality. If the scope has to change, stop and ask O, and propose the change to the design. Anything outside the scope becomes a new V2-NN task.
4.  **Prepare `wil` (A).** A new item starts only when `wil` equals `origin/main`, the working tree is clean and no pull request from `wil` is open ([Preparing `wil` after a merge](#preparing-wil-after-a-merge)). When resuming an item already started, A checks that the commits on `wil` and the open pull request belong to that item and continues on top of them; anything else is preserved and reported, never reset.
5.  **Work (A).** Small verifiable units, each ending in a check, as in [step 5 of section 10.4](designs/marlix-v0-2.md#104-the-life-of-a-task). One coherent change per commit ([Commits](#commits)).
6.  **Verify (A).** Run the checks of [step 6 of section 10.4](designs/marlix-v0-2.md#104-the-life-of-a-task). Test the real behavior in the app or in staging when the item needs it. Use an independent review when the risk justifies it (auth, RLS, crisis, spend, migrations, data deletion).
7.  **Prepare the summary (A).** Edit `status.md` as it should read once the pull request is merged. Recalculate the progress bar and mark any launch criteria this change verifies, using the rules below.
8.  **Commit and push (A, if authorized).** Check the staged diff and the [attribution rule](#no-ai-attribution), commit, and `git push origin wil`. Without authorization, A hands O the exact `git add` and `git commit` commands instead.
9.  **Open or update the pull request (A, if authorized).** `gh pr create --base main --head wil` with [the template](#pull-requests). Check the body for attribution before publishing.
10. **Watch CI (A).** `gh pr checks <n> --watch`. Fix failures caused by the change with a new commit on `wil`. Record any check still pending. Move the item to In Review only when the [In Review conditions](#board-states) hold.
11. **Merge (O, or A if the owner authorized it).** Squash merge with the pull request title (`gh pr merge <n> --squash`), only with green checks and the protections of `main` passing. If A may not merge, the pull request stays ready and the next implementation on `wil` pauses.
12. **Close out (A).** Run the [post-merge checks](#post-merge-checks), prepare `wil` for the next item, mark the item Done, and confirm that `status.md` matches the real count.

## Agent-assisted work

The maintainer works with an AI coding assistant (Claude Code with pstack). The assistant follows the same rules as any contributor, within a scope the owner authorizes for each run:

*   It may implement and test the authorized items, commit and push to `wil`, open or update the pull request from `wil` to `main`, and fix CI failures caused by the change.
*   It merges only when the owner authorized merging for that run and named the review required first (for example an independent review with no blocking findings, or the owner's approval), that review is done, the checks of the last commit are green and the protections of `main` pass. Otherwise the item stays In Review, the pull request waits for the owner, and no new implementation starts on `wil`; planning the next item without writing to `wil` is allowed.
*   Realigning `wil` after a merge is a separate authorization. An item is Done only after the merge and the post-merge checks.
*   Anything that needs new secrets, production access, spending, a scope change or an irreversible action stops and waits for the owner.
*   Commits and pull requests follow the sections below, including [No AI attribution](#no-ai-attribution). The owner reviews every pull request.

## Commits

*   [Conventional Commits](https://www.conventionalcommits.org/) in English. Use `type(scope): subject` when a scope adds clarity and `type: subject` otherwise; the history of `main` uses `type: subject`. Types in use: `feat`, `fix`, `docs`, `chore`, `test`, `ci`, `build`; `refactor` and `perf` when they fit. Scopes, when used, name the area: `api`, `app`, `db`, `site`, `infra`, `ci`.
*   The subject is imperative, lowercase after the colon, with no trailing period, for example `fix: handle LLM timeout`.
*   One coherent, verifiable change per commit. Before committing, read the staged diff (`git diff --cached`) and confirm that every file belongs to the item and that the message describes the real change.
*   Pull request merges are squash merges titled `type: summary (#PR)`.

## Pull requests

*   Title in English, in Conventional Commits form. Body from [`.github/pull_request_template.md`](../.github/pull_request_template.md), short, with these sections: `Work Item & Sprint Goal`, `Why`, `What Changed`, `Acceptance Criteria`, `Verification`, `Risks & Follow-ups`. pstack's own PR headings give way to these.
*   `Closes #N` only when the pull request fully resolves an existing issue.
*   **Evidence must be safe to publish.** Give the criterion, the check and its result: a test name, a command and its outcome, a link to a public CI run, or a screenshot with no personal data. Never paste credentials, connection strings, account or project identifiers, email addresses, private links, console screenshots or raw logs with internal data. Summarize instead, and keep the sensitive detail in the maintainer's private notes.
*   Before an item moves to In Review, A checks: the pull request goes from `wil` to `main`; the diff matches the item's scope; each ticked criterion has evidence (a test name, a command and its result, a screenshot or a log); unticked criteria say what is still to verify; and the CI state shown is that of the last pushed commit.

## No AI attribution

Commit messages and pull request descriptions carry no automatic AI signatures: no `Co-Authored-By: Claude`, no "Generated with Claude Code", no "Made with Cursor", no `Claude-Session` trailer or link to a Claude session. Legitimate human co-authors stay. Claude Code's `attribution` setting is empty in the local `.claude/settings.local.json`. Before each push A runs:

```
git log origin/main..wil --format=%B | grep -inE "co-authored-by:.*(claude|anthropic|cursor)|generated with|made with cursor|claude-session|claude\.ai/code"
```

and, before publishing or editing a pull request, the same pattern on the body (`gh pr view <n> --json body --jq .body`). Both must print nothing. Published history is not rewritten to fix a past message.

## Definition of Ready

Before C10, an item is a V2 task in the design. "Ready" in `status.md` shows eligible tasks, "In Progress" shows the work in progress, and "In Review" shows the open pull request. Dependencies come from the design. Blockers and their clearing dates are recorded in the private notes. A reopened task stops counting as verified and returns to In Progress.

An item moves from Backlog to Ready only if all of this is true:

1.  The item states the **expected outcome** in terms of what a person sees or can do.
2.  It has **acceptance criteria** that can be checked, each with a yes or no answer.
3.  It says **how to verify** them: commands, devices and steps.
4.  It lists **what blocks it**, and every blocker is closed or the item says there is none.
5.  It names its **version** (the milestone) and its **priority** (`P0`, `P1` or `P2`).
6.  It names the **launch criterion** it serves (or says that it serves none), and the **flag** if one applies.
7.  It says what is **out of scope**.
8.  It fits in about one to three sessions. If not, it is split into smaller items first.
9.  If it needs the owner (a device, a console, a decision), it says so and the owner can provide it.

## Blocked tasks and switching

Before C10, [`status.md`](#statusmd) tracks readiness, active work, reviews, and blockers. The design supplies each task's dependencies.

**One implementation item at a time.** Exactly one item is in progress on `wil`. The assistant does not start a second one for convenience.

**When a task is blocked.** Record its blocker first in the private notes, with these fields:

*   **Cause:** what is stopping the work.
*   **Depends on:** the task, condition or role it waits for (for example "C6, the owner reading the Groq console").
*   **Action to unblock:** the concrete step that lets the work continue, written so that whoever does it needs no other context.
*   **Who acts:** owner, assistant or an outside party, by role.
*   **Recorded on:** the date.

Before C10 there is no issue and no label. When the blocker clears, the date is written in the same record, which is closed once the task resumes.

**When it is right to take another task.** A blocked task stays in In Progress, paused. The assistant may take another task as the main one only when all of these hold:

1.  The blocker record is complete ([When a task is blocked](#blocked-tasks-and-switching)).
2.  The blocker will not clear in the current session, because it needs an outside action: the owner's decision, a console check, a device, a review by someone else, or time.
3.  The new task is independent: it has no dependency on the paused task, and the assistant has listed the files both touch and they do not overlap.
4.  No other task is already paused. One paused task is the limit.
5.  The new task is the highest-priority item in Ready, and it is in the approved queue.
6.  `wil` holds no unmerged commits of the paused task. If it does, the paused work must first ship as its own pull request that leaves `main` working (split the item), or the assistant stops: removing commits from `wil` rewrites it and needs the owner.

It is **not** right to switch if the blocker will probably clear in this session (for example, the owner can answer in chat), or if the blocked task has a part that does not depend on the blocker. In the second case, split that part into its own item instead of switching.

If a second task becomes blocked while one is already paused, the assistant stops taking new work and writes the unblocking action for the owner as the next step. When the blocker clears, the paused task is picked up before any Ready item of the same or lower priority.

**A pull request waiting for review.** An item in In Review is not the active implementation item, but it occupies `wil`. While the `wil` pull request waits for the owner's review or merge, no new implementation starts on `wil`; the assistant may research and plan the next item without writing to the branch. Dependabot pull requests do not count, because they use their own branches.

## Post-merge checks

After a merge: CI of `main` is green, `GET /health` answers `ok` after a backend deploy, and `docs/verify-migrations.sql` returns only `ok` after a migration. Then `wil` is [prepared for the next item](#preparing-wil-after-a-merge). If a post-merge check fails, the item is reopened: it stops counting as done and returns to In Progress.

## A clear task

Every task answers five questions. Before C10 the task is its V2-NN entry in [the design](designs/marlix-v0-2.md#detailed-implementation-plan).

| Question | Where in the issue |
|---|---|
| What result is expected? | **Expected outcome** |
| What are the acceptance criteria? | **Acceptance criteria** (checkboxes) |
| How is it verified? | **How to verify** |
| What blocks it? | **Blocked by**, and the **Blocker record** if it blocks |
| Which version is it in? | **Version** (the milestone), with **Priority** and **Launch criterion served** |

A worked example, written for the flow after C10, is in [section 10.5 of the design](designs/marlix-v0-2.md#105-a-clear-task-with-a-worked-example).

## `status.md`

[`status.md`](../status.md) is the public summary of the work. Sessions start and resume from the maintainer's private board, which `status.md` never links to. The public summary shows progress, milestones, and the items In Progress, In Review and Ready, using the [board states](#board-states). The maintainer's private notes hold the operating detail behind it: the sprint, blockers, owner actions and next steps.

### Rules

*   **Size:** it fits on one screen, about 50 lines, in English, with short lines and links instead of explanations.
*   **Layout.** Put the release progress bar, release requirements count, and Sala beta count directly below the title. Follow with "Milestones", "In Progress" (one or two sentences per item), "In Review", and "Ready" (up to five items). End with the updated date and links to the design and workflow.
*   **Milestones.** Show the main release milestones in plain English with their IDs, status, and exit conditions from the [design](designs/marlix-v0-2.md#9-sequence-and-milestones). Link to the full plan for experiments and the Sala. Mark a milestone complete when its exit conditions pass.
*   **Task names.** Put the outcome first and the ID in parentheses. The design supplies priority and dependencies. Describe progress in terms anyone can read. Immediate steps, owner actions and blocker records belong in the private notes.
*   **Keep the summary current.** Remove completed task details once the work is verified. Before C10, keep completed IDs for the release count. Git history, closed issues, and `CHANGELOG.md` carry the history.
*   **Privacy.** Record only results that are safe to publish. Keep account, billing and tester details, credentials, connection details, console screenshots, unannounced plans, open security findings and private reports outside the public repository. Follow [the security policy](../SECURITY.md#reporting-a-vulnerability) for vulnerability reports.
*   **UI method line.** While the active task is one of the UI tasks of [section 4](designs/marlix-v0-2.md#4-app-changes), "In Progress" shows `UI method: ui-ux-pro-max` with a link to the task's UI section; otherwise the line is absent.
*   **Stale check:** if the `Updated` date is older than three days, check the board (before C10, `git log` and the merged pull requests) before trusting the file.

### Interim mode (before C10)

These rules apply until the owner approves GitHub Issues and Projects for the v0.2 backlog.

*   The V2-NN list of the [Detailed Implementation Plan](designs/marlix-v0-2.md#detailed-implementation-plan) is the v0.2 backlog. Use the repository for task state and GitHub for discussion and review on existing issues and pull requests.
*   "Ready" lists up to five V2 tasks whose dependencies are all completed and verified and whose gate permits starting (V2-04 waits for C10). Use the order in [10.3](designs/marlix-v0-2.md#103-the-kanban-board) (priority, then number). Refresh the list after a task closes or a blocker clears. Experiment tasks appear only when no P0 or P1 task is eligible.
*   A task closed as not applicable is removed from the launch count (the denominator drops, for example from 28 to 27, and the scope line records why), and counts as met for the tasks that depend on it.
*   Record [blockers](#blocked-tasks-and-switching) in the private notes. `status.md` may say that an item is blocked, without the operating detail.
*   The detail of a task is its entry in [the design](designs/marlix-v0-2.md#detailed-implementation-plan). The acceptance evidence goes in the pull request body. A task with no pull request (V2-02, V2-03) is recorded in `status.md` and, when it changes a decision, in `docs/decisions.md`.
*   The stale check compares with `git log`; no board steps run.
*   Only one pull request from `wil` is open at a time, so the bars are written once per merged item. A Dependabot pull request does not touch `status.md`.

### Which event changes what

| Event | Interim (before C10) | `status.md` |
|---|---|---|
| A task is defined | A V2-NN entry is added to [the design](designs/marlix-v0-2.md#detailed-implementation-plan) | Nothing, unless the scope changes (progress section) |
| Sprint planning | Goal, items and estimates in the private notes | Nothing |
| A task becomes Ready | Its dependencies are verified | Refresh the top five in "Ready" |
| A task is taken | `wil` prepared from `main` | "In Progress" |
| A task blocks | Blocker record in the private notes | "In Progress" if another task is taken |
| The pull request opens | The body carries the acceptance evidence | Link it under "In Review" |
| The pull request merges | Nothing | Nothing: it was written in the pull request |
| The owner decides something | `docs/decisions.md` if it is a lasting technical decision; otherwise the private notes | Nothing |
| A session or run ends | Progress, blockers and next step in the private notes | Update "In Progress" if its public state changed |
| Sprint review and retrospective | Result and the chosen improvement in the private notes | Nothing |

### The update is written as if the pull request were merged

A pull request cannot contain the fact that it was merged, so it carries the state it will have after the merge: this task counted as done, the new bars, the next task as active and the new next step. The merge happens only after CI is green, so in the normal case the text is true on merge. If the pull request is rejected or changed, the edit is fixed on `wil` before the merge, and `main` never shows a state that did not happen.

### Publishing with a protected `main`, without a pull request per board move

1.  **Board moves are not commits.** Moving a card, adding a label or commenting changes nothing in the repository, so no pull request is needed.
2.  **`status.md` changes only when the summary changes** ([Which event changes what](#which-event-changes-what)). In practice that is once per task, in the pull request of that task (step 7 of [The cycle before C10](#the-cycle-before-c10)).
3.  **The operating detail never waits for a pull request,** because it lives in the private notes. `status.md` changes with the pull request of the item it describes. If the public summary is wrong between items, a short `docs:` pull request from `wil` fixes it. This is rare.
4.  **The lag is acceptable and visible.** The file shows the date of its last update. After C10 the public issues carry the live state of each item; `status.md` does not link to the private board.
5.  **A bot that commits to `main` is not proposed.** It would need a bypass in the "Protect main" rule, and every change to `main` would no longer pass through a pull request.

### The progress bars

`status.md` opens with the launch bar, the release requirements count, and a separate Sala beta count. Experiments are tracked in the design.

*   **Launch total:** after C10, the issues in the milestone `v0.2` with neither the `experiment` nor the `sala` label, minus those closed as "not planned". Before C10, the launch blockers of the [Work order](designs/marlix-v0-2.md#work-order).
*   **Done:** the tasks of that total that are completed **and verified**: the pull request is merged and the [post-merge checks](#post-merge-checks) passed. A reopened task stops counting.
*   **Percent:** the whole number below `100 × done ÷ total`. **Filled cells:** the whole number of tens in that percent, out of ten cells, so the bar never shows more than is done.
*   **Format:** `Release progress [██░░░░░░░░] 28% · 8 of 28 launch tasks verified`. On the next line, show `Requirements for release 2 of 11 met · Sala beta 2 of 6 tasks verified`.
*   **Each delivery counts once.** The unit is the task (the issue after C10), not the pull request. A task that needed three pull requests counts as one. If a task is split, the parent leaves the total and only the children count. A bug found after a task is Done is a new task and enters the total. That makes the bar move backwards, and it shows the real state.
*   **Experiments stay out.** If an experiment passes its exit criterion and joins v0.2, it enters the total, and the change is recorded in the scope line.
*   **Scope changes are visible.** The `Scope` line gives the total, the date and size of the approved scope, and the last three changes with their dates. When tasks are added or removed, the total is recomputed and the line is updated in the same edit.
*   **Launch criteria count.** "Requirements for release" counts the [launch criteria](designs/marlix-v0-2.md#8-launch-criteria) confirmed by evidence. The per-criterion checklist is kept in the private notes; a criterion that stops being true is unticked there and the count drops in the same edit.
*   **Task progress and launch readiness are counted independently.** The progress bar counts completed and verified tasks. The launch counter counts verified criteria such as the closed test, the restore drill and the policy updates. Update both when the same delivery changes both.
*   **How it is recalculated.** Before C10, from the [Work order](designs/marlix-v0-2.md#work-order) and the "Completed and verified" line. After C10, in [step 7 of section 10.4](designs/marlix-v0-2.md#104-the-life-of-a-task), the assistant lists the issues with `gh issue list --milestone v0.2 --state all --limit 200 --json number,state,stateReason,labels`, counts them by the rules above with the current task counted as done, and writes the lines. At step 13 (step 12 of [the cycle before C10](#the-cycle-before-c10)) it checks the count again.

**Before C10 (the interim bars).**

*   **Launch total:** the tasks whose **List** is `Launch` in the [Work order](designs/marlix-v0-2.md#work-order): 28 tasks (V2-01 to V2-03, V2-05a, V2-05b, V2-06a, V2-07 to V2-11, V2-12a, V2-12b, V2-13 to V2-21, V2-31 to V2-35, and V2-37). V2-04, which waits for C10, and the experiments are not counted.
*   **Sala total:** 6 tasks (V2-22 to V2-26 and V2-36).
*   **Done:** a task counts when every acceptance criterion is ticked with evidence in its pull request and the pull request is merged. A task with no pull request (V2-02, V2-03) counts when the owner confirms the result and `status.md` records it. A task whose post-merge check fails stops counting.
*   **A task that does not apply** (for example V2-03, if C1 shows the closed test is not required, or V2-12b, if C6 (d) shows a second organization brings no separate limit) is removed from the total and recorded in the scope line.
*   **The list of done tasks** is one line in `status.md`, "Completed and verified: V2-01, V2-02", and exists only before C10.
*   **At C10,** step T5 of [10.9](designs/marlix-v0-2.md#109-adopting-github-issues-and-projects-c10) maps every task to a GitHub issue, with completed tasks recorded as closed, so the totals and done counts carry over. The "Completed and verified" line is then removed.

### Automation: when it would add value

None is needed to start. The flow has about 30 tasks, one person and about one pull request a day, and the manual count is one command.

*   **A helper that prints the bar lines** (a small read-only script that uses `gh`; it changes no file and needs no secret). It adds value when the manual count is wrong or forgotten in two consecutive pull requests, or after the first ten tasks, whichever comes first.
*   **A CI check on `status.md`** (fails if the file is longer than 60 lines or contains an email address or a key-like string). It adds the most value before the closed test starts, because that is when the file might be tempted to name testers. It is the owner's call.
*   **Not proposed:** a bot that commits to `main`, and a scheduled workflow that opens a status pull request each day. The first weakens the protection of `main` and the second creates a pull request to review for no new information.

### Interim template (before C10)

Use the same layout before and after C10. Before C10, include the completed V2 IDs. After C10, track completion through the public issues; never link the private board. This example shows how the opening sections read after V2-05a passes.

```markdown
# Marlix v0.2

**Release progress** `[█░░░░░░░░░]` **10%** · 3 of 28 launch tasks verified

**Requirements for release** 0 of 11 met · **Sala beta** 0 of 6 tasks verified

- Completed and verified: V2-01, V2-02, V2-05a
- Scope: 28 launch tasks. The Sala, experiments, and V2-04 are tracked separately.

## Milestones

| Milestone | Status | Done when |
| --- | --- | --- |
| Prepare the test environment (M0) | **In progress** | Staging works end to end and a backup is restored and tested in staging. |

## In Progress

**Test a backup restore in staging (V2-05b).** The restore runs against the staging project; the data and the app sign-in are checked next.
```

Check of the numbers: 3 ÷ 28 is 10.7%, whose whole number below is 10%, so one cell is filled. No criterion is met yet: the restore drill (criterion 2) is V2-05b, still active.

## Moving to GitHub Issues and Projects (C10)

After the owner approves C10, V2-04 runs steps T1 to T8 of [10.9](designs/marlix-v0-2.md#109-adopting-github-issues-and-projects-c10). The states and fields of `status.md` map one to one:

| `status.md` before C10 | GitHub after C10 |
|---|---|
| A V2-NN entry in the design | An issue in the milestone `v0.2`, with the `V2-NN` ID in its body |
| The heading it sits under (Backlog is the design list; "Ready", "In Progress", "In Review", "Completed and verified" for Done) | The Status field of the Projects board: Backlog, Ready, In Progress, In Review, Done |
| Priority and dependencies from the design | Labels `P0`, `P1`, `P2`; "Blocked by #N" in the body |
| A blocker record (private notes) | The `blocked` label and a `## Blocker` section with only the fields that are safe to publish |
| The sprint and its approved items (private notes) | A board iteration field `Sprint` (one week), set on the approved items |
| Story points (private notes) | A number field `Points`, written once at planning and never edited |
| The "In Review" link | The pull request from `wil`, linked with `Closes #N` |

`status.md` stays the public summary and never links to the board. Sprint reviews and retrospectives stay in the private notes.

**Visibility after C10.** A private GitHub Projects board does not make the repository's issues private: every issue, label, milestone, comment and linked pull request in this public repository stays public. Board-only fields (Status, Sprint, Points) are visible only to people with access to the project. So an issue carries only what is safe to share: a title, the expected outcome, acceptance criteria and evidence that meet [the evidence rule](#pull-requests). Blocker detail, owner actions, account or billing facts, unannounced plans and open security findings stay in the private notes.
