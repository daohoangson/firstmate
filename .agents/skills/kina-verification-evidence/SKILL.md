# kina-verification-evidence

Load this before scaffolding any crewmate brief - ship or scout - that requires live `kina` verification.
`AGENTS.md` section 11 owns firstmate resolving the exact kina service name and handing over the literal `kina up <service>` command; this skill owns what counts as sufficient evidence that the crewmate actually exercised the real running service, not just that it started and reported healthy.
"I brought the service up" is not evidence by itself - require a captured, verbatim artifact of real behavior, shaped by what kind of service the PR actually touches.

## Universal requirement

Every kina-verification claim in a report or done-line must be backed by raw captured output - an exact request/response, an exact log line with a timestamp, exact model output - never a paraphrase ("it worked", "the endpoint behaved correctly").
Every claim must also be explicitly labeled live-verified against the real running service versus code-inspected-only; never blend the two silently into one confident sentence.
A short table at the end of the report - claim, how verified (live vs. code) - is the reference pattern: it makes the boundary of what was actually exercised impossible to miss.

## Evidence bar by service shape

- **Backend/API service** (a REST/RPC endpoint, a resolver, a repository method exposed over HTTP): capture the exact request sent (method, path, body) and the exact response received (status code, full or representative body) from the real running service - not a unit-test client, not an in-process function call.
- **Frontend/webapp**: a real browser render is the target - a real screenshot or captured DOM/console state from an actual browser session against an actual authenticated app, showing the actual behavior. Check `kina browser:account list` first: this fleet has a machine-wide, already-authenticated named account (the `*`-marked one is the default; the specific name and target environment vary and should never be hardcoded into a brief). Plain `kina browser` (no `--account`) uses that default account automatically - do not assume authentication is unavailable before checking this. Verify it actually yields a logged-in session before relying on it as the standard path; record the confirmed mechanics in `data/learnings.md` once proven, since this corrects an earlier wrong assumption that a QA auth wall was a standing blocker.
- **Agent/LLM-backed service** (an orchestrator, an agent loop, anything that calls a model): drive a real prompt through the real running agent and capture the actual model output, or the actual tool-schema/context sent to the model, or actual log lines with timestamps - verbatim, not a mocked LLM response and not a paraphrase of what the model "would" say. An adversarial prompt engineered to trigger the exact behavior being guarded against is strong evidence: a real model self-reporting a constraint under real pressure is stronger proof than static code reading.
- **Non-agent backend/proxy service**: same bar as backend/API - a real request through the real running process, response captured. When the fix targets a specific failure mode (a malformed input, an edge-case chunk, a race), drive that exact edge case live against the real service, or via a disclosed, deliberate fault injection when the natural trigger does not reproduce in the environment - state clearly that it was injected, not naturally observed, and why the natural trigger did not reproduce.

## Fail fast on credential or VPN failure - never fabricate a substitute

A missing or failing QA VPN connection, or a missing or failing test-account login, is a `blocked:` condition, full stop.
The crewmate reports it and stops - it does not invent, generate, mock up, or otherwise fabricate a screenshot, a rendered page, or any other artifact standing in for what it could not actually observe, and it does not silently downgrade to a weaker check and present that as if it were the real thing.
This applies even when a real, non-fabricated fallback exists (e.g. a jsdom/component-render test that exercises the real shipped code, or running a service's real compiled code directly on the host when kina-box itself cannot build it): that fallback is never the crewmate's own call to make when a credential or VPN failure is the actual cause.
Report the blocker with the exact failure (auth error, unreachable host, expired token) and let firstmate decide whether to fix the credential/VPN problem, authorize a specific named fallback for that case, or accept a genuinely reduced verification scope - never let a scout resolve that decision on its own by treating "browser access didn't work" as license to reach for whatever real-but-weaker check happens to be available.
The one thing that is always forbidden, with no exception: presenting fabricated, mocked-up, or hallucinated evidence as if it were a captured real artifact.
