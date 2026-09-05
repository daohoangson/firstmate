---
name: pr-review-scout-briefing
description: >-
  Agent-only guidance for preparing PR-review scout briefs.
  Use before scaffolding a PR-review scout's brief.
metadata:
  internal: true
---

# pr-review-scout-briefing

Load before scaffolding a PR-review scout's brief.
This guides firstmate's own brief-writing - a crewmate's worktree has no access to firstmate's `.agents/skills/`, so write each requirement directly into the brief text rather than telling the crewmate to load this skill by name.

## Anchor every review to a linked issue

Look for the linked GitHub issue or Jira bug before reviewing. When found, check the diff against its acceptance criteria one by one - treat the PR description as corroboration, and flag any place where the description disagrees with the anchor. When no anchor exists, report `needs-decision:` naming the PR and stop, so firstmate can decide how to proceed.

## Verify kina, per `kina-verification-evidence`

Bring up the kina-covered service and exercise it, even for a read-only review - the finding matters more when it's proven against the real running service.

## Look past "the check fires"

A check that runs and blocks bad input is the easy half of a review. Add these angles, each grounded in something a scout has missed before:

- **Trace the value's real contract.** Read the producer's documented shape for the value (a comment, a schema, an enum docstring), not just the consumer's check, and confirm the specific regex or validator was written for this purpose rather than borrowed from an unrelated one.
- **Search for roadmap context on naming/schema decisions.** When reviewing a design doc, look for linked product issues or prior PRs naming planned future variants of the field before judging the naming as final.
- **Follow a named sibling repo.** When the review surfaces a specific out-of-scope repo that also consumes the changed contract, treat that as the next step, not a footnote. `AGENTS.md` section 11 covers how firstmate hands over access to that repo.
- **List every topic in a human thread**, not just its resolution - a multi-comment thread can carry a second, unrelated ask worth its own finding.
- **Check the symmetric CRUD operation.** When a guardrail is added on create, check whether delete/update need the same one.

## Post findings to `report.md`; post to GitHub only on request

Write findings to `report.md` by default. When the captain asks for a GitHub review, create a fresh pending review with each comment anchored at its exact file:line.
GitHub allows one pending review per user per PR. If creating one fails because one already exists, report `blocked:` with that review's id, state, and a short summary of its content, and stop - the captain likely already knows about it and will resolve it themselves.

## Confirm the scout actually started

Check in on a freshly spawned scout within the first few minutes. Two failure modes recur: it can sit at an unconfirmed harness trust-folder prompt, or read its own unusual brief (cross-repo reads, a report path outside one project) as suspicious and stall waiting for confirmation. For the trust prompt, confirm it directly. For the second, a plain relaunch with a short, calm note - letting it re-read `brief.md` fresh - clears it faster than repeated reassurance through the same channel it already doubts.
