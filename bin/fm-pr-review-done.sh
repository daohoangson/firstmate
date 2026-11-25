#!/usr/bin/env bash
# Record that the captain is done with the PR a review task reviews, which is
# what lets bin/fm-teardown.sh clean that task up while config/pr-review-guard
# is on (bin/fm-pr-review-lib.sh owns the marker and both guards).
# Usage: fm-pr-review-done.sh <task-id>...
#   Each task must have a live record (state/<id>.meta) carrying review_pr=.
#   Run it only on the captain's own word that they are done with that PR, and
#   pass every live review round of that PR the word covers. It writes
#   data/<id>/pr-review-done with the PR and the time, and is idempotent: an
#   existing record is kept. Every id is validated before any record is
#   written, so one bad id writes nothing.
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FM_ROOT="${FM_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/.." && pwd)}"
FM_HOME="${FM_HOME:-${FM_ROOT_OVERRIDE:-$FM_ROOT}}"
STATE="${FM_STATE_OVERRIDE:-$FM_HOME/state}"
DATA="${FM_DATA_OVERRIDE:-$FM_HOME/data}"
# shellcheck source=bin/fm-pr-review-lib.sh
. "$SCRIPT_DIR/fm-pr-review-lib.sh"

usage() {
  sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  '') usage >&2; exit 2 ;;
esac

meta_pr() {  # <meta>
  awk -F= '$1 == "review_pr" { v = substr($0, index($0, "=") + 1) } END { printf "%s", v }' "$1"
}

for id in "$@"; do
  case "$id" in
    ''|.*|*[!A-Za-z0-9._-]*) echo "error: invalid task id '$id'; nothing was recorded" >&2; exit 2 ;;
  esac
  meta="$STATE/$id.meta"
  if [ ! -f "$meta" ] || [ -L "$meta" ]; then
    echo "error: task $id has no task record at $meta; nothing was recorded" >&2
    exit 1
  fi
  if [ -z "$(meta_pr "$meta")" ]; then
    echo "error: task $id is not a PR review (its record carries no review_pr=); nothing was recorded" >&2
    exit 1
  fi
done

for id in "$@"; do
  pr=$(meta_pr "$STATE/$id.meta")
  record=$(fm_pr_review_done_path "$DATA" "$id")
  if [ -f "$record" ] && [ ! -L "$record" ]; then
    echo "already recorded: captain is done with $pr for $id"
    continue
  fi
  mkdir -p "$DATA/$id"
  tmp="$record.tmp.$$"
  printf 'pr=%s\nat=%s\n' "$pr" "$(date +%s)" > "$tmp"
  mv -f "$tmp" "$record"
  echo "recorded: captain is done with $pr for $id; cleanup may proceed"
done
