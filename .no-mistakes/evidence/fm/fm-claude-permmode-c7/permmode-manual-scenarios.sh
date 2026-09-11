#!/usr/bin/env bash
# Behavior tests for fm-spawn.sh concrete dispatch profile flags.
#
# These tests drive fm-spawn through meta writing and launch construction with a
# fake tmux pane and a real isolated git worktree. The fake tmux captures the
# literal launch command sent with `tmux send-keys -l`, so assertions pin the
# command firstmate would run without starting any real harness.
set -u

# shellcheck source=tests/fixtures.sh
. "/Users/sreekaran/.no-mistakes/worktrees/3ddca7921a48/01M2920258JDBZ60BZ8MNNHQK2/tests/fixtures.sh"

SPAWN="$ROOT/bin/fm-spawn.sh"
TMP_ROOT=$(fm_test_tmproot fm-spawn-dispatch-profile)

make_spawn_pi_probe() {
  local fakebin=$1 tool=$2
  cat > "$fakebin/$tool" <<'SH'
#!/usr/bin/env bash
set -u
if [ "${1:-}" = --help ]; then
  if [ "${FM_FAKE_PI_VERSION:-0.84.0}" = 0.82.0 ]; then
    printf '%s\n' 'Pi 0.82.0' 'Options: --help'
  else
    printf '%s\n' "Pi ${FM_FAKE_PI_VERSION:-0.84.0}" 'Options: --help --tui-mode <mode>'
  fi
fi
exit 0
SH
  chmod +x "$fakebin/$tool"
}

make_spawn_fakebin() {
  local dir=$1 fakebin
  fakebin=$(fm_test_make_spawn_fakebin "$dir")
  cat > "$fakebin/timeout" <<'SH'
#!/usr/bin/env bash
shift
exec "$@"
SH
  cat > "$fakebin/cursor-agent" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = --list-models ]; then
  [ "${FM_FAKE_CURSOR_LIST_STATUS:-0}" -eq 0 ] || exit "${FM_FAKE_CURSOR_LIST_STATUS}"
  printf '%b\n' "${FM_FAKE_CURSOR_MODELS:-Available models\ncursor-grok-4.5-high - Grok 4.5 High}"
fi
exit 0
SH
  chmod +x "$fakebin/timeout" "$fakebin/cursor-agent"
  make_spawn_pi_probe "$fakebin" pi
  make_spawn_pi_probe "$fakebin" pi-signed
  printf '%s\n' "$fakebin"
}

make_spawn_case() {
  local name=$1 harness=$2 case_dir home proj wt fakebin launchlog id
  shift 2
  case_dir="$TMP_ROOT/$name"
  home="$case_dir/home"
  proj="$case_dir/project"
  wt="$case_dir/wt"
  launchlog="$case_dir/launch.log"
  fakebin=$(make_spawn_fakebin "$case_dir/fake")
  fm_test_spawn_home "$home" "$harness"
  fm_git_worktree "$proj" "$wt" "wt-$name"
  for id in "$@"; do
    fm_test_spawn_brief "$home" "$id"
  done
  printf '%s\n' "$case_dir|$home|$proj|$wt|$fakebin|$launchlog"
}

enable_dispatch_profile() {
  local home=$1
  printf '%s\n' '{"rules":[{"when":"current events","use":{"harness":"grok","model":"grok-4","effort":"high"}}],"default":{"harness":"codex","model":"gpt-5","effort":"medium"}}' \
    > "$home/config/crew-dispatch.json"
}

make_seeded_secondmate_home() {
  local home=$1 id=$2
  mkdir -p "$home/bin" "$home/data"
  printf '# Firstmate\n' > "$home/AGENTS.md"
  printf '%s\n' "$id" > "$home/.fm-secondmate-home"
  printf 'charter for %s\n' "$id" > "$home/data/charter.md"
}

run_spawn() {
  local home=$1 wt=$2 fakebin=$3 launchlog=$4
  shift 4
  : > "$launchlog"
  # CLAUDE_CONFIG_DIR is forwarded onto claude launches by fm-spawn, so pin it
  # explicitly (empty by default) instead of leaking the invoking shell's value,
  # which would make launch assertions depend on the developer's environment.
  # A test opts in to the set case via FM_TEST_CLAUDE_CONFIG_DIR.
  CLAUDE_CONFIG_DIR="${FM_TEST_CLAUDE_CONFIG_DIR:-}" \
    FM_FAKE_LAUNCH_LOG="$launchlog" FM_FAKE_PI_VERSION="${FM_TEST_PI_VERSION:-0.84.0}" \
    FM_FAKE_CURSOR_MODELS="${FM_TEST_CURSOR_MODELS:-}" \
    FM_FAKE_CURSOR_LIST_STATUS="${FM_TEST_CURSOR_LIST_STATUS:-0}" \
    GROK_HOME="$home/grok-home" \
    fm_test_run_spawn "$home" "$wt" "$fakebin" "$@"
}

# Ship spawns carry an explicit delivery contract (AGENTS.md section 7); these
# tests are about profile resolution, so they pass a fixed valid one.
run_ship_spawn() {
  run_spawn "$@" --mode no-mistakes --yolo off
}

read_case_record() {
  IFS='|' read -r CASE_DIR HOME_DIR PROJ_DIR WT_DIR FAKEBIN_DIR LAUNCH_LOG <<EOF
$1
EOF
}

assert_meta_profile() {
  local meta=$1 harness=$2 model=$3 effort=$4
  assert_grep "harness=$harness" "$meta" "meta missing harness=$harness"
  assert_grep "model=$model" "$meta" "meta missing model=$model"
  assert_grep "effort=$effort" "$meta" "meta missing effort=$effort"
}


# --- adversarial manual scenarios for config/claude-permission-mode ---------
drive_bad_token() {  # <case-name> <id> <setup-fn>
  local name=$1 id=$2 setup=$3 rec out status
  rec=$(make_spawn_case "$name" claude "$id")
  read_case_record "$rec"
  "$setup" "$HOME_DIR/config/claude-permission-mode"
  out=$(run_ship_spawn "$HOME_DIR" "$WT_DIR" "$FAKEBIN_DIR" "$LAUNCH_LOG" "$id" "$PROJ_DIR")
  status=$?
  printf '### %s\n$ fm-spawn.sh %s <project> --mode no-mistakes --yolo off\n%s\nexit=%s\nlaunch-log-bytes=%s meta-exists=%s\n\n' \
    "$name" "$id" "$out" "$status" "$(wc -c < "$LAUNCH_LOG" | tr -d ' ')" "$([ -e "$HOME_DIR/state/$id.meta" ] && echo yes || echo no)"
  expect_code 1 "$status" "$name: must refuse"
  [ ! -s "$LAUNCH_LOG" ] || fail "$name: launched something: $(cat "$LAUNCH_LOG")"
  assert_absent "$HOME_DIR/state/$id.meta" "$name: meta written despite refusal"
  pass "$name refuses before launch or metadata"
}
setup_empty()     { : > "$1"; }
setup_mixedcase() { printf 'Auto\n' > "$1"; }
setup_twotokens() { printf 'bypass auto\n' > "$1"; }
setup_dir()       { mkdir -p "$1"; }
setup_unreadable(){ printf 'auto\n' > "$1"; chmod 000 "$1"; }
drive_bad_token permmode-empty      permmode-empty-m1     setup_empty
drive_bad_token permmode-mixedcase  permmode-mixedcase-m2 setup_mixedcase
drive_bad_token permmode-twotokens  permmode-twotokens-m3 setup_twotokens
drive_bad_token permmode-dir        permmode-dir-m4       setup_dir
drive_bad_token permmode-unreadable permmode-unread-m5    setup_unreadable

# auto with --model/--effort: the flag swap leaves the profile flags intact.
rec=$(make_spawn_case permmode-auto-profile claude permmode-autoprof-m6); read_case_record "$rec"
printf 'auto\n' > "$HOME_DIR/config/claude-permission-mode"
out=$(run_ship_spawn "$HOME_DIR" "$WT_DIR" "$FAKEBIN_DIR" "$LAUNCH_LOG" permmode-autoprof-m6 "$PROJ_DIR" --model opus --effort high); status=$?
printf '### auto + --model opus --effort high\n%s\nexit=%s\nlaunch: %s\n\n' "$out" "$status" "$(cat "$LAUNCH_LOG")"
expect_code 0 "$status" "auto+profile spawn should succeed"
assert_contains "$(cat "$LAUNCH_LOG")" "claude --permission-mode auto --settings" "auto+profile: permission flag missing"
assert_contains "$(cat "$LAUNCH_LOG")" "--model 'opus' --effort 'high'" "auto+profile: profile flags missing"
assert_not_contains "$(cat "$LAUNCH_LOG")" "--dangerously-skip-permissions" "auto+profile: bypass leaked"
pass "auto keeps --model/--effort intact"

# Same home, no restart: absent -> auto -> bypass across three consecutive spawns.
rec=$(make_spawn_case permmode-toggle claude t-m7 t-m8 t-m9); read_case_record "$rec"
for step in "absent:t-m7" "auto:t-m8" "bypass:t-m9"; do
  mode=${step%%:*}; id=${step##*:}
  if [ "$mode" = absent ]; then rm -f "$HOME_DIR/config/claude-permission-mode"; else printf '%s\n' "$mode" > "$HOME_DIR/config/claude-permission-mode"; fi
  out=$(run_ship_spawn "$HOME_DIR" "$WT_DIR" "$FAKEBIN_DIR" "$LAUNCH_LOG" "$id" "$PROJ_DIR"); status=$?
  printf '### toggle step file=%s -> %s\nexit=%s\nlaunch: %s\n\n' "$mode" "$id" "$status" "$(cat "$LAUNCH_LOG")"
  expect_code 0 "$status" "toggle $mode should spawn"
  case "$mode" in
    auto) assert_contains "$(cat "$LAUNCH_LOG")" "claude --permission-mode auto --settings" "toggle: auto flag missing" ;;
    *) assert_contains "$(cat "$LAUNCH_LOG")" "claude --dangerously-skip-permissions --settings" "toggle: bypass flag missing" ;;
  esac
done
pass "the file is re-read on every spawn without a restart"
echo "# all manual permission-mode scenarios passed"
