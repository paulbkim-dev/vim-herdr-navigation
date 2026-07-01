#!/usr/bin/env bats
#
# Unit tests for navigate.sh
#
# These tests mock the `herdr` binary and control the process-info JSON to
# exercise every branch in the script without needing a real herdr install.

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
NAVIGATE="$SCRIPT_DIR/../navigate.sh"
MOCK_HERDR="$SCRIPT_DIR/helpers/mock_herdr.sh"

setup() {
  export MOCK_HERDR_LOG="$(mktemp)"
  export HERDR_BIN_PATH="$MOCK_HERDR"
  export HERDR_PANE_ID="test-pane-42"
  # Default: process info returns a non-vim process
  export MOCK_PROCESS_INFO='{"result":{"process_info":{"foreground_processes":[{"name":"bash"}]}}}'
  export MOCK_PROCESS_INFO_EXIT=0
  export HERDR_NAV_PASSTHROUGH_RE=""
}

teardown() {
  rm -f "$MOCK_HERDR_LOG"
}

# ============================================================
# Argument validation
# ============================================================

@test "fails with no arguments" {
  run bash "$NAVIGATE"
  [ "$status" -ne 0 ]
}

@test "fails with unknown direction" {
  run bash "$NAVIGATE" diagonal
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown direction"* ]]
}

# ============================================================
# Direction-to-key mapping (non-vim pane → herdr pane focus)
# ============================================================

@test "left: moves herdr focus left when foreground is not vim" {
  run bash "$NAVIGATE" left
  [ "$status" -eq 0 ]
  grep -q "pane focus --direction left --current" "$MOCK_HERDR_LOG"
}

@test "down: moves herdr focus down when foreground is not vim" {
  run bash "$NAVIGATE" down
  [ "$status" -eq 0 ]
  grep -q "pane focus --direction down --current" "$MOCK_HERDR_LOG"
}

@test "up: moves herdr focus up when foreground is not vim" {
  run bash "$NAVIGATE" up
  [ "$status" -eq 0 ]
  grep -q "pane focus --direction up --current" "$MOCK_HERDR_LOG"
}

@test "right: moves herdr focus right when foreground is not vim" {
  run bash "$NAVIGATE" right
  [ "$status" -eq 0 ]
  grep -q "pane focus --direction right --current" "$MOCK_HERDR_LOG"
}

# ============================================================
# Vim detection: forward keys to Vim
# ============================================================

@test "forwards ctrl+h to pane when nvim is the foreground process" {
  export MOCK_PROCESS_INFO='{"result":{"process_info":{"foreground_processes":[{"name":"nvim"}]}}}'
  run bash "$NAVIGATE" left
  [ "$status" -eq 0 ]
  grep -q "pane send-keys test-pane-42 ctrl+h" "$MOCK_HERDR_LOG"
}

@test "forwards ctrl+j when vim is the foreground process" {
  export MOCK_PROCESS_INFO='{"result":{"process_info":{"foreground_processes":[{"name":"vim"}]}}}'
  run bash "$NAVIGATE" down
  [ "$status" -eq 0 ]
  grep -q "pane send-keys test-pane-42 ctrl+j" "$MOCK_HERDR_LOG"
}

@test "forwards ctrl+k when vi is the foreground process" {
  export MOCK_PROCESS_INFO='{"result":{"process_info":{"foreground_processes":[{"name":"vi"}]}}}'
  run bash "$NAVIGATE" up
  [ "$status" -eq 0 ]
  grep -q "pane send-keys test-pane-42 ctrl+k" "$MOCK_HERDR_LOG"
}

@test "forwards ctrl+l when view is the foreground process" {
  export MOCK_PROCESS_INFO='{"result":{"process_info":{"foreground_processes":[{"name":"view"}]}}}'
  run bash "$NAVIGATE" right
  [ "$status" -eq 0 ]
  grep -q "pane send-keys test-pane-42 ctrl+l" "$MOCK_HERDR_LOG"
}

@test "forwards when gvim is the foreground process" {
  export MOCK_PROCESS_INFO='{"result":{"process_info":{"foreground_processes":[{"name":"gvim"}]}}}'
  run bash "$NAVIGATE" left
  [ "$status" -eq 0 ]
  grep -q "pane send-keys test-pane-42 ctrl+h" "$MOCK_HERDR_LOG"
}

@test "forwards when vimdiff is the foreground process" {
  export MOCK_PROCESS_INFO='{"result":{"process_info":{"foreground_processes":[{"name":"vimdiff"}]}}}'
  run bash "$NAVIGATE" right
  [ "$status" -eq 0 ]
  grep -q "pane send-keys test-pane-42 ctrl+l" "$MOCK_HERDR_LOG"
}

@test "forwards when nvimdiff is the foreground process" {
  export MOCK_PROCESS_INFO='{"result":{"process_info":{"foreground_processes":[{"name":"nvimdiff"}]}}}'
  run bash "$NAVIGATE" down
  [ "$status" -eq 0 ]
  grep -q "pane send-keys test-pane-42 ctrl+j" "$MOCK_HERDR_LOG"
}

# ============================================================
# Non-vim process: herdr pane focus (no forward)
# ============================================================

@test "does not forward when foreground is htop" {
  export MOCK_PROCESS_INFO='{"result":{"process_info":{"foreground_processes":[{"name":"htop"}]}}}'
  run bash "$NAVIGATE" left
  [ "$status" -eq 0 ]
  grep -q "pane focus --direction left --current" "$MOCK_HERDR_LOG"
  ! grep -q "pane send-keys" "$MOCK_HERDR_LOG"
}

@test "does not forward when foreground is zsh" {
  export MOCK_PROCESS_INFO='{"result":{"process_info":{"foreground_processes":[{"name":"zsh"}]}}}'
  run bash "$NAVIGATE" right
  [ "$status" -eq 0 ]
  grep -q "pane focus --direction right --current" "$MOCK_HERDR_LOG"
  ! grep -q "pane send-keys" "$MOCK_HERDR_LOG"
}

# ============================================================
# Passthrough regex: opt-in forwarding for non-vim TUIs
# ============================================================

@test "forwards when HERDR_NAV_PASSTHROUGH_RE matches lazygit" {
  export HERDR_NAV_PASSTHROUGH_RE='^(lazygit|vi-sql)$'
  export MOCK_PROCESS_INFO='{"result":{"process_info":{"foreground_processes":[{"name":"lazygit"}]}}}'
  run bash "$NAVIGATE" down
  [ "$status" -eq 0 ]
  grep -q "pane send-keys test-pane-42 ctrl+j" "$MOCK_HERDR_LOG"
}

@test "forwards when HERDR_NAV_PASSTHROUGH_RE matches vi-sql" {
  export HERDR_NAV_PASSTHROUGH_RE='^(lazygit|vi-sql)$'
  export MOCK_PROCESS_INFO='{"result":{"process_info":{"foreground_processes":[{"name":"vi-sql"}]}}}'
  run bash "$NAVIGATE" up
  [ "$status" -eq 0 ]
  grep -q "pane send-keys test-pane-42 ctrl+k" "$MOCK_HERDR_LOG"
}

@test "does not forward for non-matching process when passthrough is set" {
  export HERDR_NAV_PASSTHROUGH_RE='^(lazygit)$'
  export MOCK_PROCESS_INFO='{"result":{"process_info":{"foreground_processes":[{"name":"htop"}]}}}'
  run bash "$NAVIGATE" right
  [ "$status" -eq 0 ]
  grep -q "pane focus --direction right --current" "$MOCK_HERDR_LOG"
  ! grep -q "pane send-keys" "$MOCK_HERDR_LOG"
}

# ============================================================
# Edge cases: HERDR_PANE_ID unset or empty → skip detection
# ============================================================

@test "skips vim detection when HERDR_PANE_ID is empty" {
  export HERDR_PANE_ID=""
  export MOCK_PROCESS_INFO='{"result":{"process_info":{"foreground_processes":[{"name":"nvim"}]}}}'
  run bash "$NAVIGATE" left
  [ "$status" -eq 0 ]
  grep -q "pane focus --direction left --current" "$MOCK_HERDR_LOG"
  ! grep -q "pane send-keys" "$MOCK_HERDR_LOG"
}

@test "skips vim detection when HERDR_PANE_ID is unset" {
  unset HERDR_PANE_ID
  export MOCK_PROCESS_INFO='{"result":{"process_info":{"foreground_processes":[{"name":"nvim"}]}}}'
  run bash "$NAVIGATE" right
  [ "$status" -eq 0 ]
  grep -q "pane focus --direction right --current" "$MOCK_HERDR_LOG"
  ! grep -q "pane send-keys" "$MOCK_HERDR_LOG"
}

# ============================================================
# Edge case: jq not available → skip detection, move pane focus
# ============================================================

@test "moves herdr focus when jq is not in PATH" {
  # Override PATH to exclude jq (keep only our mock dir and basic utils)
  export PATH="$(dirname "$MOCK_HERDR"):/usr/bin:/bin"
  # Verify jq is actually absent from this PATH
  if command -v jq >/dev/null 2>&1; then
    skip "jq found in restricted PATH, cannot isolate"
  fi
  export MOCK_PROCESS_INFO='{"result":{"process_info":{"foreground_processes":[{"name":"nvim"}]}}}'
  run bash "$NAVIGATE" left
  [ "$status" -eq 0 ]
  grep -q "pane focus --direction left --current" "$MOCK_HERDR_LOG"
  ! grep -q "pane send-keys" "$MOCK_HERDR_LOG"
}

# ============================================================
# Edge case: herdr process-info fails → fallback to pane focus
# ============================================================

@test "moves herdr focus when process-info command fails" {
  export MOCK_PROCESS_INFO_EXIT=1
  export MOCK_PROCESS_INFO=''
  run bash "$NAVIGATE" up
  [ "$status" -eq 0 ]
  grep -q "pane focus --direction up --current" "$MOCK_HERDR_LOG"
  ! grep -q "pane send-keys" "$MOCK_HERDR_LOG"
}

# ============================================================
# Edge case: empty foreground_processes array
# ============================================================

@test "moves herdr focus when foreground_processes is empty" {
  export MOCK_PROCESS_INFO='{"result":{"process_info":{"foreground_processes":[]}}}'
  run bash "$NAVIGATE" down
  [ "$status" -eq 0 ]
  grep -q "pane focus --direction down --current" "$MOCK_HERDR_LOG"
  ! grep -q "pane send-keys" "$MOCK_HERDR_LOG"
}

# ============================================================
# Case insensitivity: Vim detection matches regardless of case
# ============================================================

@test "forwards when foreground is NVIM (uppercase)" {
  export MOCK_PROCESS_INFO='{"result":{"process_info":{"foreground_processes":[{"name":"NVIM"}]}}}'
  run bash "$NAVIGATE" left
  [ "$status" -eq 0 ]
  grep -q "pane send-keys test-pane-42 ctrl+h" "$MOCK_HERDR_LOG"
}

@test "forwards when foreground is Vim (mixed case)" {
  export MOCK_PROCESS_INFO='{"result":{"process_info":{"foreground_processes":[{"name":"Vim"}]}}}'
  run bash "$NAVIGATE" down
  [ "$status" -eq 0 ]
  grep -q "pane send-keys test-pane-42 ctrl+j" "$MOCK_HERDR_LOG"
}

# ============================================================
# Custom HERDR_BIN_PATH respected
# ============================================================

@test "uses HERDR_BIN_PATH when set" {
  # The mock is already set via HERDR_BIN_PATH in setup
  run bash "$NAVIGATE" left
  [ "$status" -eq 0 ]
  # The log file exists and was written to, proving our mock was called
  [ -s "$MOCK_HERDR_LOG" ]
}
