# Workflow

How a v0.2 task goes from start to merge before C10, the owner's approval to adopt GitHub Issues and Projects for the v0.2 backlog. These rules come from section 10 of the [v0.2 design](designs/marlix-v0-2.md#10-marlix-v02-development-flow), approved on 2026-11-20. The board rules, labels and steps in [10.4](designs/marlix-v0-2.md#104-the-life-of-a-task) and [10.9](designs/marlix-v0-2.md#109-adopting-github-issues-and-projects-c10) take effect in V2-04.

**A** is the assistant and **O** is the owner.

## The cycle before C10

The life of a task ([10.4](designs/marlix-v0-2.md#104-the-life-of-a-task)) without a board or issues.

1.  **Start the session (A).** Read `status.md`, run `git status` and `git log -5`, and check the CI of `main`. If `status.md` disagrees with `git log` and the merged pull requests, fix `status.md`.
2.  **Choose (A, O agrees).** Refresh "Ready to start" against the design and take its first task. If a task is already active or paused, apply the switching rules ([Blocked tasks and switching](#blocked-tasks-and-switching)).
3.  **Take it (A).** Mark it as the active task in `status.md` and re-read its entry in [the design](designs/marlix-v0-2.md#detailed-implementation-plan) against reality. If the scope has to change, tell the owner first and propose the change to the design. Anything outside the scope becomes a new V2-NN task.
4.  **Branch (A).** `<type>/<short-description>` from an up-to-date `main`.
5.  **Work (A).** As in [step 5 of section 10.4](designs/marlix-v0-2.md#104-the-life-of-a-task).
6.  **Verify (A).** Run the checks of [step 6 of section 10.4](designs/marlix-v0-2.md#104-the-life-of-a-task), and write the evidence for each acceptance criterion in the pull request body.
7.  **Prepare the summary (A).** Edit `status.md` as it should read once the pull request is merged. Recalculate the task progress bar and mark any launch criteria this change verifies, using the rules below.
8.  **Hand over (A).** As in [step 8 of section 10.4](designs/marlix-v0-2.md#104-the-life-of-a-task).
9.  **Commit and push (O).** Run the commands and say "ready".
10. **Open the pull request (A).** `gh pr create` with an English body: the task ID, the acceptance evidence, "How to test" and the Definition of Done checklist.
11. **Watch CI (A).** `gh pr checks <n> --watch`; a failure is fixed on the same branch.
12. **Merge (O).** Squash merge with the title and commit list the assistant provides; the owner deletes the remote branch and says "merged".
13. **Close out (A).** Sync `main`, delete the local branch, run the [post-merge checks](#post-merge-checks), and confirm that `status.md` matches the real count.

## Definition of Ready

Before C10, an issue is a V2 task in the design. "Ready to start" shows eligible tasks, "Active task" shows the work in progress, and "In review" shows open pull requests. Dependencies come from the design. Record blockers and clearing dates under "Blocked". A reopened task stops counting as verified and becomes the active task.

An item moves from Backlog to Ready only if all of this is true:

1.  The issue states the **expected outcome** in terms of what a person sees or can do.
2.  It has **acceptance criteria** that can be checked, each with a yes or no answer.
3.  It says **how to verify** them: commands, devices and steps.
4.  It lists **what blocks it**, and every blocker is closed or the item says there is none.
5.  It names its **version** (the milestone) and its **priority** (`P0`, `P1` or `P2`).
6.  It names the **launch criterion** it serves (or says that it serves none), and the **flag** if one applies.
7.  It says what is **out of scope**.
8.  It fits in about one to three sessions. If not, it is split into smaller issues first.
9.  If it needs the owner (a device, a console, a decision), it says so and the owner can provide it.

## Blocked tasks and switching

Before C10, [`status.md`](#statusmd) tracks readiness, active work, reviews, and blockers. The design supplies each task's dependencies.

**One main task at a time.** Exactly one task is the active main task. The assistant does not start a second one for convenience.

**When a task is blocked.** Record its blocker first under "Blocked" in `status.md`. A compact table can carry the same fields:

*   **Cause:** what is stopping the work.
*   **Depends on:** the task, condition or role it waits for (for example "C6, the owner reading the Groq console").
*   **Action to unblock:** the concrete step, written so that whoever does it needs no other context.
*   **Who acts:** owner, assistant or an outside party, by role.
*   **Recorded on:** the date.

Before C10 there is no issue and no label. When the blocker clears, the date is written in the same Blocked section of `status.md`, and the record is removed from it once the task resumes.

**When it is right to take another task.** A blocked task stays in In Progress, paused. The assistant may take another task as the main one only when all of these hold:

1.  The blocker record is complete ([When a task is blocked](#blocked-tasks-and-switching)).
2.  The blocker will not clear in the current session, because it needs an outside action: the owner's decision, a console check, a device, a review by someone else, or time.
3.  The new task is independent: it has no "Blocked by" link to the paused task, and the assistant has listed the files both touch and they do not overlap.
4.  No other task is already paused. One paused task is the limit.
5.  The new task is the highest-priority item in Ready.

It is **not** right to switch if the blocker will probably clear in this session (for example, the owner can answer in chat), or if the blocked task has a part that does not depend on the blocker. In the second case, split that part into its own issue instead of switching.

If a second task becomes blocked while one is already paused, the assistant stops taking new work and writes the unblocking action for the owner as the next step. When the blocker clears, the paused task is picked up before any Ready item of the same or lower priority.

**A pull request waiting for review.** A task in In Review is not the active main task. The next task may start while the pull request waits, if it meets conditions 3 and 5 of [When it is right to take another task](#blocked-tasks-and-switching). At most two items sit in In Review.

## Post-merge checks

After a merge: CI of `main` is green, `GET /health` answers `ok` after a backend deploy, and `docs/verify-migrations.sql` returns only `ok` after a migration. If a post-merge check fails, the task is reopened: it stops counting as done and becomes the active task again.

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

[`status.md`](../status.md) is the entry point of every session. Read "Active task" and "To finish", then open the task in the design for scope, dependencies, and acceptance criteria. With pstack in Claude Code, use `/pstack:poteto-mode` with the task's outcome and the evidence needed to close it. Follow the same verification and owner handoff.

### Rules

*   **Size:** it fits on one screen, about 70 lines, in English, with short lines and links instead of explanations.
*   **Layout.** Put the release progress bar, release requirements count, and Sala beta count directly below the title. Follow with "Milestones", "Active task", "In review", "Ready to start" (up to five tasks), "Blocked", "Launch checklist", "Owner decisions", and "Later" (up to five items). End with the updated date and links to the design and workflow.
*   **Milestones.** Show the main release milestones in plain English with their IDs, status, and exit conditions from the [design](designs/marlix-v0-2.md#9-sequence-and-milestones). Link to the full plan for experiments and the Sala. Mark a milestone complete when its exit conditions pass.
*   **Task names.** Put the outcome first and the ID in parentheses. The design supplies priority and dependencies. Keep the immediate steps in a single "To finish" entry under "Active task", with the evidence and the person responsible for each action where needed.
*   **Keep the summary current.** Remove completed task details once the work is verified. Before C10, keep completed IDs for the release count. Git history, closed issues, and `CHANGELOG.md` carry the history.
*   **Privacy.** Record the result of each external check and its effect on the work. Keep account, billing and tester details, credentials, console screenshots, and private reports outside the public repository. Follow [the security policy](../SECURITY.md#reporting-a-vulnerability) for vulnerability reports.
*   **UI method line.** While the active task is one of the UI tasks of [section 4](designs/marlix-v0-2.md#4-app-changes), "Active task" shows `UI method: ui-ux-pro-max` with a link to the task's UI section; otherwise the line is absent.
*   **Stale check:** if the `Updated` date is older than three days, check the board (before C10, `git log` and the merged pull requests) before trusting the file.

### Interim mode (before C10)

These rules apply until the owner approves GitHub Issues and Projects for the v0.2 backlog.

*   The V2-NN list of the [Detailed Implementation Plan](designs/marlix-v0-2.md#detailed-implementation-plan) is the v0.2 backlog. Use the repository for task state and GitHub for discussion and review on existing issues and pull requests.
*   "Ready to start" lists up to five V2 tasks whose dependencies are all completed and verified and whose gate permits starting (V2-04 waits for C10). Use the order in [10.3](designs/marlix-v0-2.md#103-the-kanban-board) (priority, then number). Refresh the list after a task closes or a blocker clears. Experiment tasks appear only when no P0 or P1 task is eligible.
*   A task closed as not applicable is removed from the launch count (the denominator drops, for example from 28 to 27, and the scope line records why), and counts as met for the tasks that depend on it.
*   Record [blockers](#blocked-tasks-and-switching) under "Blocked". A dependency can share the same table with other blockers.
*   The detail of a task is its entry in [the design](designs/marlix-v0-2.md#detailed-implementation-plan). The acceptance evidence goes in the pull request body. A task with no pull request (V2-02, V2-03) is recorded in `status.md` and, when it changes a decision, in `docs/decisions.md`.
*   The stale check compares with `git log`; no board steps run.
*   When two pull requests wait in review, only the one merged second updates the bars, after a rebase on `main`.

### Which event changes what

| Event | Interim (before C10) | `status.md` |
|---|---|---|
| A task is defined | A V2-NN entry is added to [the design](designs/marlix-v0-2.md#detailed-implementation-plan) | Nothing, unless the scope changes (progress section) |
| A task becomes Ready | Its dependencies are verified | Refresh the top five in "Ready to start" |
| A task is taken | Branch created | "Active task" |
| A task blocks | Blocker record in `status.md` | "Blocked", and "Active task" if another task is taken |
| The pull request opens | The body carries the acceptance evidence | Link it under "In review" |
| The pull request merges | Nothing | Nothing: it was written in the pull request |
| The owner decides something | `docs/decisions.md` if lasting | Update "Owner decisions" |
| A session ends | Nothing | Update the active task's "To finish" entry |

### The update is written as if the pull request were merged

A pull request cannot contain the fact that it was merged, so it carries the state it will have after the merge: this task counted as done, the new bars, the next task as active and the new next step. The owner merges only after CI is green, so in the normal case the text is true on merge. If the pull request is rejected or changed, the edit is fixed in the same branch before the merge, and `main` never shows a state that did not happen.

### Publishing with a protected `main`, without a pull request per board move

1.  **Board moves are not commits.** Moving a card, adding a label or commenting changes nothing in the repository, so no pull request is needed.
2.  **`status.md` changes only when the summary changes** ([Which event changes what](#which-event-changes-what)). In practice that is once per task, in the pull request of that task (step 7 of [The cycle before C10](#the-cycle-before-c10)).
3.  **At the end of a session with no pull request in flight,** the assistant edits `status.md` in the working tree and the owner includes it in the next commit. If a branch is already open, that is its last commit. If waiting for the next task would hurt (a blocker the next session must see, an owner decision), a short `docs/status-update` branch and a `docs:` pull request are used. This is rare.
4.  **The lag is acceptable and visible.** The file shows the date of its last update and, after C10, links to the board, which is always current.
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
*   **Launch checkboxes.** Keep the 11 criteria in order under "Launch checklist". Mark a criterion `- [x]` once evidence confirms it. Restore `- [ ]` if the criterion stops being true. Update "Requirements for release" in the same edit.
*   **Task progress and launch readiness are counted independently.** The progress bar counts completed and verified tasks. The launch counter counts verified criteria such as the closed test, the restore drill and the policy updates. Update both when the same delivery changes both.
*   **How it is recalculated.** Before C10, from the [Work order](designs/marlix-v0-2.md#work-order) and the "Completed and verified" line. After C10, in [step 7 of section 10.4](designs/marlix-v0-2.md#104-the-life-of-a-task), the assistant lists the issues with `gh issue list --milestone v0.2 --state all --limit 200 --json number,state,stateReason,labels`, counts them by the rules above with the current task counted as done, and writes the lines. At step 13 it checks the count again.

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
*   **A CI check on `status.md`** (fails if the file is longer than 80 lines or contains an email address or a key-like string). It adds the most value before the closed test starts, because that is when the file might be tempted to name testers. It is the owner's call.
*   **Not proposed:** a bot that commits to `main`, and a scheduled workflow that opens a status pull request each day. The first weakens the protection of `main` and the second creates a pull request to review for no new information.

### Interim template (before C10)

Use the same layout before and after C10. Before C10, include the completed V2 IDs. After C10, show the board link and track completion through the issues. This example shows how the opening sections read after V2-05a passes.

```markdown
# Marlix v0.2

**Release progress** `[█░░░░░░░░░]` **10%** · 3 of 28 launch tasks verified

**Requirements for release** 0 of 11 met · **Sala beta** 0 of 6 tasks verified

- Completed and verified: V2-01, V2-02, V2-05a
- Scope: 28 launch tasks. The Sala, experiments, and V2-04 are tracked separately.

## Milestones

| Milestone | Status | Done when |
| --- | --- | --- |
| Prepare the test environment (M0) | **In progress** | The Google Play path is defined and a backup is restored and tested in staging. |

## Active task
**Test a backup restore in staging (V2-05b)**

- **To finish:** Restore the backup, verify the data, and sign in from the app.
```

Check of the numbers: 3 ÷ 28 is 10.7%, whose whole number below is 10%, so one cell is filled. No criterion is met yet: the restore drill (criterion 2) is V2-05b, still active.
