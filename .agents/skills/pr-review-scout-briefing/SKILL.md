# pr-review-scout-briefing

Load this before scaffolding a PR-review scout's brief.
This skill is the single owner of what a PR-review scout brief must require, beyond the generic scout scaffold.
It exists because two rounds of real review dispatches showed the generic scaffold alone lets a scout miss exactly the class of finding a human reviewer catches.

## Anchor requirement (hard rule)

Every reviewed PR - feature or bug fix, no exceptions - must trace to a linked GitHub issue or Jira bug before a scout reviews it.
If the scout cannot find one, it stops and escalates a decision to firstmate rather than reviewing anyway; it never silently falls back to reviewing against only the PR's own description.
When an anchor exists, require the scout to treat it as the primary source of truth: check the diff against the anchor's actual acceptance criteria one by one, not against what the PR description claims.
The PR description becomes secondary corroboration - a mismatch between the description and the anchor is itself a finding (a stale or overstating description), not the main check.

## Kina verification

`AGENTS.md` section 11 owns firstmate resolving the exact kina service name before dispatch, and `kina-verification-evidence` owns what counts as sufficient proof - both apply to a review scout exactly as they do to any ship task.
A review brief always requires live kina verification when the touched service is kina-covered, even though the PR itself is read-only investigation - the whole point is exercising the real running service, not just reading the diff.
If a scout's report surfaces a kina-box tooling gap (a service that cannot build cleanly, missing credential wiring, etc.), record it in `data/learnings.md` - that is fleet-local operational fact, not brief content.

## Beyond "does the check fire" - checklist items to fold into every review-scout brief

Ordinary review instructions ask a scout to verify a check exists and blocks bad input, and run correctly.
That alone repeatedly missed what a real human reviewer caught. Require these additional angles:

- **Whose contract is this?** When the diff adds or changes a validation rule, an enum-based dispatch, or a regex-based gate, do not stop at "the check fires and blocks bad input." Require the scout to find and read the *producer's* documented contract for that value (a comment, a schema doc, an enum's own docstring), not only the *consumer's* code path, and to check whether the specific check or regex reused here was originally written for a different purpose elsewhere in the codebase before treating "it blocks bad input" as sufficient.
- **Roadmap search for naming/schema decisions.** When a scout reviews a design or spec doc (not code) for a naming or schema decision, have it explicitly search for linked product issues, roadmap docs, or prior related PRs that name planned future variants of the same field, rather than only validating internal consistency of the doc as written.
- **Named sibling-repo follow-up is mandatory, not a caveat.** When a scout's own investigation identifies a specific out-of-scope sibling repo that also consumes the changed value or contract (a shared enum, a regex, a wire format, a pipeline contract), that is a trigger for a second, targeted pass into that named repo before the review counts as done - not a sentence noting it as out of scope. A correctly-scoped-but-cross-repo-breaking change is exactly the kind of bug a human institutional reviewer catches and a single-repo review misses. `AGENTS.md` section 11 owns how the scout actually gets access to that repo (it never clones one itself); this is the review-specific reason that access gets triggered.
- **Enumerate multi-topic human threads.** When a scout report summarizes a multi-comment human review thread, require it to enumerate each distinct topic raised, not just the thread's final resolution. A one-line "naming bikeshed, resolved" summary can silently drop a separate, substantive ask buried in the same thread.
- **CRUD lifecycle symmetry.** For any CRUD-shaped feature (params, secrets, any resource with create/update/delete), require the scout to check whether a guardrail (a warning, a confirmation, a validation) added on one lifecycle operation has the same guardrail on the symmetric operation.

## Confirm the scout actually started

After spawning a review scout, confirm within the first few minutes that it is genuinely processing the brief, not sitting at an unconfirmed harness trust-folder prompt or a false self-triggered suspicion that its own brief is a prompt injection (both have occurred in real dispatches - a scout given a brief with unusual read/write shape, such as reading firstmate's own cross-repo data or writing a report outside a single project, has more than once treated its own legitimate scaffold as suspicious).
If a scout gets stuck in the latter loop, do not escalate with repeated persuasive reassurance messages sent through the same steering channel it already distrusts - that has reinforced the loop rather than resolved it.
A plain relaunch with a short, non-alarming note, letting the scout re-read its own `brief.md` fresh, has recovered cleanly where repeated reassurance did not.
