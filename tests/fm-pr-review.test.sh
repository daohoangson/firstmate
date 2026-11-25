#!/usr/bin/env bash
# Behavior tests for the PR-review task marker and its opt-in guards
# (bin/fm-pr-review-lib.sh): the scout brief declaration written by
# bin/fm-brief.sh --pr-review, the spawn-time head and prior-report check in
# bin/fm-spawn.sh, and the captain done-record bin/fm-pr-review-done.sh writes.
# The teardown refusal is covered in tests/fm-teardown.test.sh, which owns the
# full cleanup fixture.
#
# Every spawn case stops before any endpoint exists: the review checks run
# ahead of backend creation, and a fake `tmux` that exits non-zero backstops the
# cases meant to get past them. A fake `gh` reports the PR's current head.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SPAWN="$ROOT/bin/fm-spawn.sh"
BRIEF="$ROOT/bin/fm-brief.sh"
DONE="$ROOT/bin/fm-pr-review-done.sh"
TMP_ROOT=$(fm_test_tmproot fm-pr-review)
PR=https://github.com/acme/widgets/pull/42
HEAD_A=1111111111111111111111111111111111111111
HEAD_B=2222222222222222222222222222222222222222

# Echoes "<home>|<project-dir>|<fakebin>". The fake gh prints $FAKE_GH_HEAD for
# `gh pr view ... headRefOid`, or fails when it is empty.
make_home() {  # <name>
  local name=$1 home proj fakebin
  home="$TMP_ROOT/$name/home"
  proj="$TMP_ROOT/$name/projects/proj"
  fakebin="$TMP_ROOT/$name/bin"
  mkdir -p "$home/data" "$home/state" "$home/config" "$proj" "$fakebin"
  git -C "$proj" init -q || fail "could not initialize project fixture"
  git -c user.name=test -c user.email=test@example.com -C "$proj" commit -q --allow-empty -m init \
    || fail "could not commit project fixture"
  printf '#!/bin/sh\nexit 1\n' > "$fakebin/tmux"
  cat > "$fakebin/gh" <<'SH'
#!/bin/sh
[ -n "${FAKE_GH_HEAD:-}" ] || { echo "gh: not reachable" >&2; exit 1; }
case "$*" in
  "pr view "*headRefOid*) printf '%s\n' "$FAKE_GH_HEAD" ;;
  *) exit 1 ;;
esac
SH
  chmod +x "$fakebin/tmux" "$fakebin/gh"
  printf '%s\n' "$home|$proj|$fakebin"
}

scaffold_review() {  # <home> <id> <head> [<prior-report>]
  local home=$1 id=$2 head=$3 prior=${4:-}
  if [ -n "$prior" ]; then
    FM_HOME="$home" "$BRIEF" "$id" proj --scout --pr-review "$PR" --pr-head "$head" --prior-report "$prior" >/dev/null 2>&1
  else
    FM_HOME="$home" "$BRIEF" "$id" proj --scout --pr-review "$PR" --pr-head "$head" >/dev/null 2>&1
  fi || fail "review brief $id should scaffold"
  local content
  content=$(cat "$home/data/$id/brief.md")
  content=${content//'{TASK}'/Review the widget change.}
  content=${content//'{FIRSTMATE_SPEC}'/Check the selected focus entries.}
  printf '%s\n' "$content" > "$home/data/$id/brief.md"
}

run_spawn() {  # <home> <fakebin> <gh-head> <spawn-args...>
  local home=$1 fakebin=$2 gh_head=$3
  shift 3
  FAKE_GH_HEAD=$gh_head FM_ROOT_OVERRIDE='' FM_HOME="$home" \
    FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
    FM_PROJECTS_OVERRIDE="$TMP_ROOT/projects-unused" FM_CONFIG_OVERRIDE="$home/config" \
    FM_SPAWN_NO_GUARD=1 FM_BACKEND=tmux PATH="$fakebin:$PATH" \
    "$SPAWN" "$@" 2>&1
}

test_brief_declares_the_review_and_refuses_bad_parts() {
  local rec home proj fakebin out brief
  rec=$(make_home brief)
  IFS='|' read -r home proj fakebin <<EOF
$rec
EOF
  scaffold_review "$home" rv-brief "$HEAD_A" "$home/data/prior/report.md"
  brief="$home/data/rv-brief/brief.md"
  assert_grep "PR review: $PR head=$HEAD_A prior-report=$home/data/prior/report.md" "$brief" \
    "the review brief did not declare the PR, head, and prior report under Setup"
  assert_grep "$home/data/rv-brief/evidence/" "$brief" \
    "the review brief did not send evidence to the task's data directory"

  out=$(FM_HOME="$home" "$BRIEF" rv-nohead proj --scout --pr-review "$PR" 2>&1) \
    && fail "a review brief without --pr-head should refuse"
  assert_contains "$out" "--pr-head" "the missing-head refusal did not name --pr-head"
  out=$(FM_HOME="$home" "$BRIEF" rv-short proj --scout --pr-review "$PR" --pr-head abc123 2>&1) \
    && fail "an abbreviated head should refuse"
  assert_contains "$out" "40-character" "the short-head refusal did not name the full SHA"
  out=$(FM_HOME="$home" "$BRIEF" rv-rel proj --scout --pr-review "$PR" --pr-head "$HEAD_A" --prior-report data/x.md 2>&1) \
    && fail "a relative prior report should refuse"
  assert_contains "$out" "absolute path" "the relative-path refusal did not name the rule"
  out=$(FM_HOME="$home" "$BRIEF" rv-ship proj --mode direct-PR --pr-review "$PR" --pr-head "$HEAD_A" 2>&1) \
    && fail "a ship brief should refuse --pr-review"
  assert_contains "$out" "only to scout briefs" "the ship refusal did not name the scout-only rule"
  pass "fm-brief: --pr-review declares the reviewed PR and head and refuses malformed parts"
}

test_spawn_guard_is_off_without_the_flag() {
  local rec home proj fakebin out
  rec=$(make_home guard-off)
  IFS='|' read -r home proj fakebin <<EOF
$rec
EOF
  scaffold_review "$home" rv-off "$HEAD_A" "$home/data/missing/report.md"
  out=$(run_spawn "$home" "$fakebin" "$HEAD_B" rv-off "$proj" claude --scout)
  assert_not_contains "$out" "current head" "the head check ran without config/pr-review-guard"
  assert_not_contains "$out" "names prior report" "the prior-report check ran without config/pr-review-guard"
  pass "fm-spawn: without config/pr-review-guard a stale review brief is not checked"
}

test_spawn_refuses_a_stale_review_brief() {
  local rec home proj fakebin out status
  rec=$(make_home guard-on)
  IFS='|' read -r home proj fakebin <<EOF
$rec
EOF
  : > "$home/config/pr-review-guard"

  scaffold_review "$home" rv-stale "$HEAD_A"
  out=$(run_spawn "$home" "$fakebin" "$HEAD_B" rv-stale "$proj" claude --scout)
  status=$?
  [ "$status" -ne 0 ] || fail "a brief naming an old head should be refused"
  assert_contains "$out" "current head is $HEAD_B" "the stale-head refusal did not name the PR's current head"
  assert_absent "$home/state/rv-stale.meta" "the stale-head refusal wrote a task record"

  out=$(run_spawn "$home" "$fakebin" "" rv-stale "$proj" claude --scout)
  status=$?
  [ "$status" -ne 0 ] || fail "an unreadable PR head should be refused"
  assert_contains "$out" "could not be read" "the unreadable-head refusal did not say so"

  scaffold_review "$home" rv-prior "$HEAD_A" "$home/data/rv-r1/report.md"
  out=$(run_spawn "$home" "$fakebin" "$HEAD_A" rv-prior "$proj" claude --scout)
  status=$?
  [ "$status" -ne 0 ] || fail "a re-review naming a missing prior report should be refused"
  assert_contains "$out" "no such file exists" "the prior-report refusal did not say the file is missing"
  assert_absent "$home/state/rv-prior.meta" "the prior-report refusal wrote a task record"

  mkdir -p "$home/data/rv-r1"
  printf 'Prior round.\n' > "$home/data/rv-r1/report.md"
  out=$(run_spawn "$home" "$fakebin" "$HEAD_A" rv-prior "$proj" claude --scout)
  assert_not_contains "$out" "current head" "a fresh review brief was refused on its head"
  assert_not_contains "$out" "names prior report" "an existing prior report was refused"
  pass "fm-spawn: config/pr-review-guard refuses a stale head, an unreadable head, and a missing prior report"
}

test_spawn_refuses_a_malformed_declaration_without_the_flag() {
  local rec home proj fakebin out status brief
  rec=$(make_home malformed)
  IFS='|' read -r home proj fakebin <<EOF
$rec
EOF
  scaffold_review "$home" rv-dup "$HEAD_A"
  brief="$home/data/rv-dup/brief.md"
  awk -v line="PR review: $PR head=$HEAD_B" '{ print } /^PR review:/ { print line }' "$brief" > "$brief.tmp"
  mv "$brief.tmp" "$brief"
  out=$(run_spawn "$home" "$fakebin" "$HEAD_A" rv-dup "$proj" claude --scout)
  status=$?
  [ "$status" -ne 0 ] || fail "a brief declaring two PR reviews should be refused"
  assert_contains "$out" "invalid PR review declaration" "the duplicate declaration was not named"
  assert_absent "$home/state/rv-dup.meta" "the malformed declaration wrote a task record"
  pass "fm-spawn: a duplicated PR review declaration refuses even with the guard off"
}

test_done_record_requires_a_review_task() {
  local rec home proj fakebin out
  rec=$(make_home done-record)
  IFS='|' read -r home proj fakebin <<EOF
$rec
EOF
  fm_write_meta "$home/state/rv-a.meta" "kind=scout" "review_pr=$PR"
  fm_write_meta "$home/state/plain.meta" "kind=scout"
  out=$(FM_HOME="$home" "$DONE" rv-a plain 2>&1) && fail "a non-review task should refuse the done record"
  assert_contains "$out" "not a PR review" "the refusal did not say the task is not a review"
  assert_absent "$home/data/rv-a/pr-review-done" "a refused batch still wrote a record"

  out=$(FM_HOME="$home" "$DONE" rv-a 2>&1) || fail "the done record should be written: $out"
  assert_grep "pr=$PR" "$home/data/rv-a/pr-review-done" "the done record did not name the PR"
  out=$(FM_HOME="$home" "$DONE" rv-a 2>&1) || fail "a repeated done record should succeed: $out"
  assert_contains "$out" "already recorded" "a repeated done record was not reported as kept"
  pass "fm-pr-review-done: records the captain's word only for review tasks, all-or-nothing"
}

test_brief_declares_the_review_and_refuses_bad_parts
test_spawn_guard_is_off_without_the_flag
test_spawn_refuses_a_stale_review_brief
test_spawn_refuses_a_malformed_declaration_without_the_flag
test_done_record_requires_a_review_task
echo "# all fm-pr-review tests passed"
