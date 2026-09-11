#!/usr/bin/env bash
# fm-control.sh relaunch: the transactional replace-the-agent verb.
#
# Relaunch is the only control verb that changes durable records, so these
# tests pin the transaction itself, hermetically (stubbed session provider, no
# real agent):
#   1. A same-harness relaunch keeps every identity axis and reuses the SAME
#      endpoint and worktree - it replaces an agent, it never forks a task.
#   2. A harness switch is one ordinary relaunch: the record follows, the
#      previous harness's per-task wiring is cleared, and profile axes chosen
#      for the old harness do not silently carry to the new one.
#   3. The progress note is required where the replacement needs it, lands in
#      the instructions the replacement reads, and never rewrites a charter.
#   4. A refusal before the agent is stopped changes nothing.
#   5. A launch failure after the agent is stopped keeps the prior record,
#      reports the concrete state, and preserves the work.
#   6. fm-spawn --relaunch refuses on its own: a live agent, a contradicting
#      flag, an extra positional, or a backend that cannot prove the previous
#      agent exited.
set -u

# shellcheck source=tests/lib.sh
. "/Users/sreekaran/.no-mistakes/worktrees/3ddca7921a48/01M2920258JDBZ60BZ8MNNHQK2/tests/lib.sh"
# shellcheck source=/dev/null
. "$ROOT/bin/fm-control-lib.sh"
# shellcheck source=/dev/null
. "$ROOT/bin/fm-trace-context-lib.sh"

CONTROL="$ROOT/bin/fm-control.sh"
SPAWN="$ROOT/bin/fm-spawn.sh"
PROMOTE="$ROOT/bin/fm-promote.sh"
X_LINK="$ROOT/bin/fm-x-link.sh"
# fm_test_tmproot's own cleanup trap fires when its command substitution exits,
# so recreate the root before resolving it and clean it up from this file's trap.
TMP_ROOT=$(fm_test_tmproot fm-control-relaunch)
mkdir -p "$TMP_ROOT"
TMP_ROOT=$(cd "$TMP_ROOT" && pwd)
TASK_TMPS=()

relaunch_cleanup() {
  local d
  for d in "${TASK_TMPS[@]:-}"; do
    [ -n "$d" ] && rm -rf "$d"
  done
  rm -rf "$TMP_ROOT"
}
trap relaunch_cleanup EXIT

# The same lifecycle-modelling tmux stub as tests/fm-control.test.sh: the
# harness's exit command stops the agent, and a launch-brief literal starts the
# harness named in `becomes`.
make_tmux_stub() {  # <dir>
  local fb="$1/fakebin"
  mkdir -p "$fb"
  cat > "$fb/tmux" <<'SH'
#!/usr/bin/env bash
set -u
D=$FM_FAKE_DIR
case "${1:-}" in
  send-keys)
    shift
    literal=0
    while [ $# -gt 0 ]; do
      case "$1" in
        -t) shift 2 ;;
        -l) literal=1; shift ;;
        *) break ;;
      esac
    done
    payload=${1:-}
    if [ "$literal" = 1 ]; then
      printf '%s\n' "$payload" >> "$D/literal"
      case "$payload" in
        /exit|/quit)
          printf 'zsh' > "$D/command"
          [ -z "${FM_FAKE_EXIT_TRANSPORT_FAIL_AFTER_STOP:-}" ] || exit 1
          ;;
        *'encode launch-brief'*)
          cat "$D/becomes" > "$D/command"
          [ -z "${FM_FAKE_LAUNCH_TRANSPORT_FAIL_AFTER_START:-}" ] || exit 1
          ;;
      esac
    else
      printf '%s\n' "$payload" >> "$D/keys"
      case "$payload" in
        'export GOTMPDIR='*)
          if [ -n "${FM_FAKE_TRACE_PREPARE:-}" ]; then
            : > "$FM_FAKE_TRACE_PREPARE"
            while [ ! -e "$FM_FAKE_TRACE_RELEASE" ]; do /bin/sleep 0.01; done
          fi
          ;;
        'export TRACEPARENT='*)
          [ -z "${FM_FAKE_TRACE_EXPORTED:-}" ] || : > "$FM_FAKE_TRACE_EXPORTED"
          ;;
      esac
    fi
    exit 0 ;;
  display-message)
    for a in "$@"; do
      case "$a" in
        *cursor_y*) printf '1\n'; exit 0 ;;
        *pane_current_command*) cat "$D/command"; printf '\n'; exit 0 ;;
        *pane_current_path*)
          if [ -n "${FM_FAKE_CWD_RACE_READY:-}" ]; then
            : > "$FM_FAKE_CWD_RACE_READY"
            /bin/sleep 1
          fi
          cat "$D/cwd"; printf '\n'; exit 0 ;;
      esac
    done
    printf 'fakepane\n'; exit 0 ;;
  capture-pane) printf '╭────╮\n│    │\n╰────╯\n'; exit 0 ;;
  list-windows) [ -f "$D/windows" ] && cat "$D/windows"; exit 0 ;;
esac
exit 0
SH
  chmod +x "$fb/tmux"
  cat > "$fb/sleep" <<'SH'
#!/usr/bin/env bash
[ -z "${FM_FAKE_LOCK_WAITING:-}" ] || : > "$FM_FAKE_LOCK_WAITING"
exit 0
SH
  chmod +x "$fb/sleep"
}

# new_case <name> [id] -> echoes a case dir with a live claude ship task.
new_case() {
  local id=${2:-t1} dir="$TMP_ROOT/$1-$RANDOM"
  mkdir -p "$dir/home/state" "$dir/home/data" "$dir/fake"
  : > "$dir/fake/literal"
  : > "$dir/fake/keys"
  printf 'claude' > "$dir/fake/command"
  printf 'claude' > "$dir/fake/becomes"
  printf '%s\n' "fm-$id" > "$dir/fake/windows"
  make_tmux_stub "$dir"
  printf '%s\n' "$dir"
}

# add_ship_task <case-dir> <id> [harness]
add_ship_task() {
  local dir=$1 id=$2 harness=${3:-claude}
  local home="$dir/home" proj="$dir/proj" wt="$dir/wt"
  fm_git_worktree "$proj" "$wt" "task-$id"
  mkdir -p "$home/data/$id"
  cat > "$home/data/$id/brief.md" <<EOF
# Task
## Captain's intent
Exercise relaunch behavior for $id.

## Firstmate spec
Preserve the task while replacing its agent process.
EOF
  {
    echo "window=fmses:fm-$id"
    echo "endpoint_task_id=$id"
    echo "worktree=$wt"
    echo "project=$proj"
    echo "harness=$harness"
    echo "kind=ship"
    echo "mode=no-mistakes"
    echo "yolo=off"
    echo "tasktmp=/tmp/fm-$id"
    echo "model=default"
    echo "effort=default"
  } > "$home/state/$id.meta"
  printf '%s\n' "fm-$id" > "$dir/fake/windows"
  printf '%s' "$wt" > "$dir/fake/cwd"
  TASK_TMPS+=("/tmp/fm-$id")
}

run_control() {  # <case-dir> <args...>
  local dir=$1; shift
  # A claude spawn pre-registers workspace trust in the launching user's own
  # store (bin/fm-claude-trust.sh), and a relaunch reaches it through fm-control.sh, so this runs against a throwaway HOME;
  # without it this suite would write the developer's real ~/.claude.json.
  mkdir -p "$dir/user-home"
  env PATH="$dir/fakebin:$PATH" FM_HOME="$dir/home" FM_FAKE_DIR="$dir/fake" \
    HOME="$dir/user-home" CLAUDE_CONFIG_DIR='' \
    FM_SPAWN_NO_GUARD=1 GROK_HOME="$dir/grokhome" \
    FM_CONTROL_POLL=0.01 FM_CONTROL_EXIT_WAIT=0.05 FM_CONTROL_LAUNCH_WAIT=0.05 \
    FM_REAL_GIT="${FM_REAL_GIT:-}" FM_FAKE_GIT_FAILURE="${FM_FAKE_GIT_FAILURE:-}" \
    FM_REAL_MV="${FM_REAL_MV:-}" FM_FAKE_COMPLETE_JOURNAL_MV_FAIL="${FM_FAKE_COMPLETE_JOURNAL_MV_FAIL:-}" \
    FM_FAKE_META_PUBLISH_MV_FAIL="${FM_FAKE_META_PUBLISH_MV_FAIL:-}" \
    FM_FAKE_TRACE_PREPARE="${FM_FAKE_TRACE_PREPARE:-}" \
    FM_FAKE_TRACE_RELEASE="${FM_FAKE_TRACE_RELEASE:-}" \
    FM_FAKE_META_WRITER_READY="${FM_FAKE_META_WRITER_READY:-}" \
    FM_FAKE_TRACE_EXPORTED="${FM_FAKE_TRACE_EXPORTED:-}" \
    "$CONTROL" "$@" 2>&1
}

run_spawn() {  # <case-dir> <args...>
  local dir=$1; shift
  # A claude spawn pre-registers workspace trust in the launching user's own
  # store (bin/fm-claude-trust.sh), so it runs against a throwaway HOME;
  # without it this suite would write the developer's real ~/.claude.json.
  mkdir -p "$dir/user-home"
  env PATH="$dir/fakebin:$PATH" FM_HOME="$dir/home" FM_FAKE_DIR="$dir/fake" \
    HOME="$dir/user-home" CLAUDE_CONFIG_DIR='' \
    FM_SPAWN_NO_GUARD=1 GROK_HOME="$dir/grokhome" \
    "$SPAWN" "$@" 2>&1
}

meta_field() {  # <case-dir> <id> <key>
  grep "^$3=" "$1/home/state/$2.meta" | tail -1 | cut -d= -f2-
}

journal_field() {  # <case-dir> <id> <key>
  grep "^$3=" "$1/home/state/$2.control-relaunch" | tail -1 | cut -d= -f2-
}

# --- relaunch scenarios for config/claude-permission-mode -------------------
# 1. auto reaches a control-plane relaunch of an existing claude task.
dir=$(new_case permmode-relaunch pm1)
add_ship_task "$dir" pm1 claude
mkdir -p "$dir/home/config"
printf 'auto\n' > "$dir/home/config/claude-permission-mode"
printf 'zsh' > "$dir/fake/command"   # previous agent has exited
out=$(run_spawn "$dir" pm1 --relaunch); status=$?
printf '### relaunch under auto\n$ fm-spawn.sh pm1 --relaunch\n%s\nexit=%s\nliteral sent to pane:\n%s\n\n' "$out" "$status" "$(cat "$dir/fake/literal")"
expect_code 0 "$status" "relaunch under auto should succeed"
assert_contains "$out" "spawned pm1 harness=claude" "relaunch did not report claude"
assert_contains "$(cat "$dir/fake/literal")" "claude --permission-mode auto --settings" "relaunch did not carry --permission-mode auto"
assert_not_contains "$(cat "$dir/fake/literal")" "--dangerously-skip-permissions" "relaunch requested bypass"
[ "$(meta_field "$dir" pm1 harness)" = claude ] || fail "relaunch changed harness"
pass "config/claude-permission-mode=auto reaches a relaunch of an existing claude task"

# 2. an invalid token refuses the relaunch and leaves the existing record untouched.
dir=$(new_case permmode-relaunch-bad pm2)
add_ship_task "$dir" pm2 claude
mkdir -p "$dir/home/config"
printf 'yolo\n' > "$dir/home/config/claude-permission-mode"
printf 'zsh' > "$dir/fake/command"
before=$(cat "$dir/home/state/pm2.meta")
out=$(run_spawn "$dir" pm2 --relaunch); status=$?
printf '### relaunch under invalid token\n$ fm-spawn.sh pm2 --relaunch\n%s\nexit=%s\nliteral-bytes=%s\n\n' "$out" "$status" "$(wc -c < "$dir/fake/literal" | tr -d ' ')"
expect_code 1 "$status" "invalid token must refuse relaunch"
assert_contains "$out" "config/claude-permission-mode holds 'yolo'" "refusal did not name token"
[ ! -s "$dir/fake/literal" ] || fail "invalid token relaunch sent keys: $(cat "$dir/fake/literal")"
[ "$(cat "$dir/home/state/pm2.meta")" = "$before" ] || fail "invalid token relaunch mutated meta"
pass "an invalid token refuses a relaunch before touching the pane or the record"
echo "# all relaunch permission-mode scenarios passed"
