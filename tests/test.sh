#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT

export HERDR_BIN_PATH="$repo/tests/mock-herdr.sh"
export HERDR_NAV_TEST_LOG="$tmp/herdr.log"
export HERDR_PANE_ID=w-test:p1

assert_command() {
  local expected=$1
  local actual
  actual=$(tail -n 1 "$HERDR_NAV_TEST_LOG")
  if [[ $actual != "$expected" ]]; then
    printf 'expected command: %s\nactual command:   %s\n' "$expected" "$actual" >&2
    exit 1
  fi
}

export HERDR_NAV_TEST_PROCESS=nvim
"$repo/navigate.sh" left
assert_command 'pane send-keys w-test:p1 ctrl+h'

export HERDR_NAV_TEST_PROCESS=zsh
"$repo/navigate.sh" down
assert_command 'pane focus --direction down --pane w-test:p1'

export HERDR_NAV_TEST_PROCESS=lazygit
export HERDR_NAV_PASSTHROUGH_RE='^lazygit$'
"$repo/navigate.sh" up
assert_command 'pane send-keys w-test:p1 ctrl+k'

export HERDR_NAV_PASSTHROUGH_RE='['
"$repo/navigate.sh" right
assert_command 'pane focus --direction right --pane w-test:p1'

unset HERDR_PANE_ID HERDR_NAV_PASSTHROUGH_RE
"$repo/navigate.sh" right
assert_command 'pane focus --direction right --current'

if "$repo/navigate.sh" sideways >/dev/null 2>&1; then
  printf 'unknown direction unexpectedly succeeded\n' >&2
  exit 1
fi

# Stale HERDR_BIN_PATH (e.g. the server binary was replaced by `herdr update`
# without a server restart, leaving ".../herdr (deleted)"): fall back to `herdr`
# on PATH.
rm -f "$HERDR_NAV_TEST_LOG"
mkdir -p "$tmp/bin"
cat >"$tmp/bin/herdr" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$HERDR_NAV_TEST_LOG"
EOF
chmod +x "$tmp/bin/herdr"
HERDR_PANE_ID=w-test:p1 HERDR_BIN_PATH="$tmp/nonexistent-herdr" PATH="$tmp/bin:$PATH" \
  "$repo/navigate.sh" right
assert_command 'pane focus --direction right --pane w-test:p1'

# Stale HERDR_BIN_PATH and nothing usable on PATH: fail loudly instead of
# silently doing nothing.
# Run bash by absolute path: with PATH emptied, the env shebang would fail first.
if HERDR_PANE_ID=w-test:p1 HERDR_BIN_PATH="$tmp/nonexistent-herdr" PATH="$tmp/empty" \
    "$BASH" "$repo/navigate.sh" right >/dev/null 2>"$tmp/stderr"; then
  printf 'stale binary with no PATH fallback unexpectedly succeeded\n' >&2
  exit 1
fi
grep -q 'no usable herdr binary' "$tmp/stderr"

rm -f "$HERDR_NAV_TEST_LOG"
export HERDR_NAV_TEST_REPO="$repo"
export HERDR_PANE_ID=w-test:p1
env -u TMUX nvim --clean --headless -u NONE -l "$repo/tests/nvim.lua"

rm -f "$HERDR_NAV_TEST_LOG"
env -u TMUX nvim --clean --headless -u NONE -S "$repo/tests/vim.vim"
printf 'Vimscript navigation verification passed\n'

# Inside the Herdr desktop app there is no HERDR_PANE_ID; the edge crossing goes
# through `herdr-app do pane.go`, which acts on the app's focused pane.
cat >"$tmp/bin/herdr-app" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$HERDR_NAV_TEST_LOG"
EOF
chmod +x "$tmp/bin/herdr-app"
for editor in "-l $repo/tests/nvim.lua" "-S $repo/tests/vim.vim"; do
  rm -f "$HERDR_NAV_TEST_LOG"
  # shellcheck disable=SC2086
  env -u TMUX -u HERDR_PANE_ID HC_TERMINAL_ID=t1 PATH="$tmp/bin:$PATH" \
    HERDR_NAV_TEST_EXPECT='do pane.go --direction right' \
    nvim --clean --headless -u NONE $editor
done
printf 'Herdr app navigation verification passed\n'

printf 'Herdr navigation verification passed\n'
