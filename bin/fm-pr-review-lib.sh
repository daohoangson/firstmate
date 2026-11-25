# shellcheck shell=bash
# PR-review task marker, spawn-time freshness check, and captain done-record.
# Usage: . bin/fm-pr-review-lib.sh
#
# This file is the single owner of what makes a task a PR review and of the
# two opt-in guards built on that marker. The procedure firstmate follows for
# review intake and cleanup lives in .agents/skills/pr-review/SKILL.md.
#
# Marker: a scout brief whose `# Setup` section carries exactly one line
#   PR review: <pr-url> head=<40-hex sha>[ prior-report=<absolute path>]
# written by bin/fm-brief.sh --pr-review. A task-id prefix is never read as a
# marker. bin/fm-spawn.sh records the URL as review_pr=<pr-url> in
# state/<id>.meta for every such scout, guard or no guard, and a relaunch keeps
# it; a malformed or duplicated declaration refuses the spawn.
#
# Guards, both active only while the local, gitignored config/pr-review-guard
# presence flag exists (docs/configuration.md "PR-review guard"):
#   - bin/fm-spawn.sh refuses a fresh review launch whose declared head differs
#     from the PR's current head on GitHub (`gh pr view <url> --json
#     headRefOid`), whose head cannot be read, or whose declared prior-report
#     path is not an existing file.
#   - bin/fm-teardown.sh refuses a kind=scout task recording review_pr= until
#     data/<id>/pr-review-done exists. bin/fm-pr-review-done.sh writes that
#     record after the captain says they are done with the PR; --force does not
#     lift this refusal, because it authorizes discarding work, never the
#     captain's keep-alive rule.

# shellcheck source=bin/fm-brief-heading-lib.sh
. "$(d=${BASH_SOURCE[0]%/*}; [ "$d" != "${BASH_SOURCE[0]}" ] || d=.; cd "${d:-/}" && pwd)/fm-brief-heading-lib.sh"

FM_PR_REVIEW_URL=
FM_PR_REVIEW_HEAD=
FM_PR_REVIEW_PRIOR=
FM_PR_REVIEW_ERROR=

# Render the declaration line from its parts; bin/fm-brief.sh writes it.
fm_pr_review_line() {  # <pr-url> <head> [<prior-report>]
  printf 'PR review: %s head=%s' "$1" "$2"
  [ -z "${3:-}" ] || printf ' prior-report=%s' "$3"
  printf '\n'
}

# Validate the declaration's parts; sets FM_PR_REVIEW_ERROR on refusal.
fm_pr_review_parts_valid() {  # <pr-url> <head> <prior-report>
  FM_PR_REVIEW_ERROR=
  if ! [[ $1 =~ ^https://[^[:space:]/]+/[^[:space:]/]+/[^[:space:]/]+/pull/[0-9]+$ ]]; then
    FM_PR_REVIEW_ERROR="the PR must be a full https://<host>/<owner>/<repo>/pull/<number> URL (got '$1')"
    return 1
  fi
  if ! [[ $2 =~ ^[0-9a-f]{40}$ ]]; then
    FM_PR_REVIEW_ERROR="the head must be the PR's full 40-character lowercase commit SHA (got '$2')"
    return 1
  fi
  case "$3" in
    ''|/*) ;;
    *) FM_PR_REVIEW_ERROR="the prior report must be an absolute path (got '$3')"; return 1 ;;
  esac
  case "$3" in
    *[[:cntrl:]]*) FM_PR_REVIEW_ERROR="the prior report path must not contain control characters"; return 1 ;;
  esac
}

# Read the declaration from a brief's `# Setup` section.
# Returns 0 and sets FM_PR_REVIEW_URL/HEAD/PRIOR when declared, 1 when the
# brief declares no PR review, and 2 with FM_PR_REVIEW_ERROR when the
# declaration is duplicated or malformed.
fm_pr_review_parse() {  # <brief>
  local setup lines count line rest url head prior=
  FM_PR_REVIEW_URL='' FM_PR_REVIEW_HEAD='' FM_PR_REVIEW_PRIOR='' FM_PR_REVIEW_ERROR=''
  setup=$(fm_brief_heading_body "$1" "# Setup")
  lines=$(printf '%s\n' "$setup" | LC_ALL=C grep '^PR review:' || true)
  [ -n "$lines" ] || return 1
  count=$(printf '%s\n' "$lines" | wc -l | tr -d '[:space:]')
  if [ "$count" != 1 ]; then
    FM_PR_REVIEW_ERROR="the # Setup section declares $count PR review lines; a review task reviews exactly one PR"
    return 2
  fi
  line=$lines
  rest=${line#PR review: }
  url=${rest%% *}
  rest=${rest#"$url"}
  case "$rest" in
    ' head='*) rest=${rest# head=} ;;
    *) FM_PR_REVIEW_ERROR="the PR review line must read 'PR review: <pr-url> head=<sha>[ prior-report=<path>]' (got '$line')"; return 2 ;;
  esac
  head=${rest%% *}
  rest=${rest#"$head"}
  case "$rest" in
    '') ;;
    ' prior-report='?*) prior=${rest# prior-report=} ;;
    *) FM_PR_REVIEW_ERROR="the PR review line must read 'PR review: <pr-url> head=<sha>[ prior-report=<path>]' (got '$line')"; return 2 ;;
  esac
  fm_pr_review_parts_valid "$url" "$head" "$prior" || return 2
  FM_PR_REVIEW_URL=$url FM_PR_REVIEW_HEAD=$head FM_PR_REVIEW_PRIOR=$prior
}

fm_pr_review_guard_enabled() {  # <config-dir>
  [ -e "$1/pr-review-guard" ] || [ -L "$1/pr-review-guard" ]
}

fm_pr_review_done_path() {  # <data-dir> <task-id>
  printf '%s/%s/pr-review-done\n' "$1" "$2"
}

# Spawn-time freshness check for a parsed declaration. Prints the refusal and
# returns 1 when the brief is stale.
fm_pr_review_spawn_check() {  # <brief>
  local current
  if ! current=$(gh pr view "$FM_PR_REVIEW_URL" --json headRefOid -q .headRefOid 2>/dev/null) || [ -z "$current" ]; then
    echo "error: $1 declares a review of $FM_PR_REVIEW_URL, but its current head could not be read from GitHub; check gh authentication and the URL, then retry the spawn" >&2
    return 1
  fi
  if [ "$current" != "$FM_PR_REVIEW_HEAD" ]; then
    echo "error: $1 declares head $FM_PR_REVIEW_HEAD for $FM_PR_REVIEW_URL, but the PR's current head is $current; rebuild the brief's Firstmate spec for the current head with bin/fm-brief.sh --pr-review (pr-review skill) rather than editing an earlier brief" >&2
    return 1
  fi
  if [ -n "$FM_PR_REVIEW_PRIOR" ] && [ ! -f "$FM_PR_REVIEW_PRIOR" ]; then
    echo "error: $1 names prior report $FM_PR_REVIEW_PRIOR for this re-review, but no such file exists; point --prior-report at the report of the round that reviewed the prior head" >&2
    return 1
  fi
}

# Teardown check: prints the refusal and returns 1 while the captain has not
# released this review task.
fm_pr_review_teardown_check() {  # <data-dir> <task-id> <pr-url>
  local record
  record=$(fm_pr_review_done_path "$1" "$2")
  [ -f "$record" ] && [ ! -L "$record" ] && return 0
  echo "error: task $2 reviews $3 and stays alive until the captain says they are done with that PR; nothing was changed" >&2
  echo "remedy: once the captain says they are done with $3, copy any evidence outside data/$2/evidence/ there, run bin/fm-pr-review-done.sh $2, then retry cleanup" >&2
  return 1
}
