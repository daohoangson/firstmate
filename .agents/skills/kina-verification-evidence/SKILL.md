# kina-verification-evidence

Load before scaffolding any ship or scout brief that requires live `kina` verification.
`AGENTS.md` section 11 resolves the exact kina service name; this skill defines what counts as proof the crewmate exercised the real running service.
This guides firstmate's own brief-writing - write each requirement directly into the brief text; a crewmate's worktree has no access to firstmate's `.agents/skills/`.

## Capture the real artifact

Require raw output for every verification claim: the exact request/response, the exact log line with a timestamp, the exact model output. Label each claim live-verified or code-inspected-only, and keep the two labels visibly separate - a short table (claim | how verified) at the end of the report works well.

## Match the evidence to the service shape

- **Backend/API**: capture the exact request sent and exact response received (status + body) from the real running service.
- **Frontend/webapp**: drive a real browser session and capture a screenshot or the real DOM/console state. Check `kina browser:account list` for an already-authenticated account before assuming one is needed; the default (no `--account` flag) uses whichever account is marked `*`. Confirm the session is genuinely logged in before relying on it, and record the confirmed mechanics in `data/learnings.md` once proven.
- **Agent/LLM-backed service**: drive a real prompt through the real running agent and capture the actual model output or tool-schema/context sent to it, verbatim. An adversarial prompt that tries to trigger the guarded behavior is strong evidence - a real model self-reporting a constraint under pressure beats static code reading.
- **Non-agent backend/proxy**: same bar as backend/API. For a fix targeting a specific failure mode, drive that exact case live; when the natural trigger won't reproduce, use a disclosed, deliberate fault injection and say so plainly.

## When a credential or VPN check fails

Report it as `blocked:` with the exact failure (auth error, unreachable host, expired token), and stop there. Let firstmate decide the next step - fix the credential/VPN issue, authorize a specific fallback for that case, or accept a reduced verification scope. This decision point exists precisely because a fallback that looks reasonable to the crewmate (a component-render test, a host-run substitute) may or may not be the right call for that specific finding, and only firstmate has that context.
Report exactly what was captured, and only what was captured - a screenshot, log line, or response body goes in the report exactly as observed.
