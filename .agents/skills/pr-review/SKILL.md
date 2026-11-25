---
name: pr-review
description: Load before dispatching, re-dispatching, or cleaning up any PR-review task - a scout that reviews an existing pull request.
user-invocable: false
metadata:
  internal: true
---

# PR review intake and cleanup

A PR-review task is a scout whose deliverable is a review report on someone's existing pull request.
Follow every step below for each review and each re-review round, because an earlier brief carries an earlier head, an earlier focus, and earlier mistakes.
`bin/fm-pr-review-lib.sh` owns the review marker and the two opt-in guards that enforce steps 3 and 5; its header owns their exact rules.

## 1. Inventory the PR

- Run `gh pr view <url> --json title,body,files,author,baseRefName,headRefOid,closingIssuesReferences`.
- Read the linked issues and any companion PRs the body, the issues, or the branch name point at.
- Run the group check: when companion PRs ship one change together, they get one review task covering the group, not one task per PR.
- Before dispatching a round, read the captain's latest word on that PR, so a closed or cancelled review is not dispatched again, and check that no round is already queued for this head.

## 2. Build the Firstmate spec from the home's review files

Build `## Firstmate spec` from the home's review files every time, never from an earlier brief.
The home keeps them, when it has them, at two `data/` paths:

- `data/review-spec.md` - the standing review instructions this home applies to every review.
- `data/review-focus.md` - the focus map: entries keyed by changed paths or PR signals, each naming focus areas and how to verify them.

Then write the brief's spec from:

- the review instructions from `data/review-spec.md` that apply to this PR;
- only the `data/review-focus.md` entries whose paths or signals match this PR's inventory, unioned across a group;
- one to five PR-specific hypotheses drawn from the diff and the linked intent;
- the threat-model scope, such as a private repository, test credentials, a feature flag that is off, or a developer-only tool.

Paste nothing else from the focus map, so an unselected area cannot leak into the report.
A captain focus given for one PR goes in that brief's `## Captain's intent`, not into the home's files, until the captain says it is general.
When the home has neither file, write the spec from the inventory and the captain's words alone.

## 3. Declare the PR, its head, and any prior report

Scaffold the brief with `bin/fm-brief.sh <id> <repo> --scout --pr-review <pr-url> --pr-head <sha>`, adding `--prior-report <path>` for a re-review.
Take the head from step 1's `headRefOid`, never from an earlier brief.
For a re-review, pass the report of the round that reviewed the prior head and confirm that report names that head.
With `config/pr-review-guard` on, the spawn refuses a declared head the PR no longer has and a prior report that does not exist (docs/configuration.md "PR-review guard").

## 4. Keep evidence beside the report

The review brief tells the worker to save evidence in the home's `data/<task-id>/evidence/`, beside `data/<task-id>/report.md`.
Evidence left only in the worker's copy is lost at cleanup.

## 5. Keep the worker until the captain is done with the PR

Never clean up a PR-review worker after its report.
The worker stays alive for follow-up questions and later rounds until the captain says they are done with that PR.
On that word, copy any evidence still inside the worker's copy into `data/<task-id>/evidence/`, record it with `bin/fm-pr-review-done.sh <task-id>...` for every live review task of that PR, and only then clean up.
With `config/pr-review-guard` on, cleanup refuses a review task without that record, even with `--force`.

## 6. Learn into the focus map

Update `data/review-focus.md` with a date and a pointer to the evidence, editing the matching entry rather than appending:

- after a captain correction or added focus, edit the entry for those paths, or add one when the focus is new;
- after a withdrawn or downgraded finding, add the check to verify first;
- after a miss found later by another reviewer, a human, or the captain, add the check that would have found it;
- when an area keeps coming back empty on a path, drop it from that entry.
