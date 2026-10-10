#!/usr/bin/env bash
#
# vim-herdr-navigation — herdr side
#
# Invoked by a herdr keybind as: navigate.sh [--no-detect] <left|down|up|right>
#
# If the focused pane is running Vim/Neovim in the foreground, hand the matching
# Ctrl chord to that pane so Vim moves between its own splits (and, at a split
# edge, calls back into herdr to cross the pane boundary — see editor/*). The same
# forwarding can be turned on for other TUIs that own Ctrl+h/j/k/l themselves via
# HERDR_NAV_PASSTHROUGH_RE (off by default — see below). For any other foreground
# process, move herdr's pane focus directly.
#
# --no-detect skips the Vim check and goes straight to moving herdr's focus. The
# editor side calls in that way once Vim is out of splits, so that crossing out
# of Vim behaves exactly like crossing out of any other pane (spillover below).
#
# Requires `jq`. Without it, detection is skipped and every key just moves the
# herdr pane focus (no Vim awareness).

set -euo pipefail

detect=1
if [ "${1:-}" = --no-detect ]; then
  detect=0
  shift
fi

dir="${1:?usage: navigate.sh [--no-detect] <left|down|up|right>}"
herdr="${HERDR_BIN_PATH:-herdr}"
# After `herdr update` replaces the binary under a still-running server, the
# server-injected HERDR_BIN_PATH points at the deleted inode (reported as
# ".../herdr (deleted)"), so every exec would fail with 127. Fall back to PATH.
if ! [ -x "$herdr" ]; then
  herdr="$(command -v herdr || true)"
fi
if [ -z "$herdr" ]; then
  echo "navigate.sh: no usable herdr binary (HERDR_BIN_PATH stale and herdr not on PATH)" >&2
  exit 127
fi
pane="${HERDR_PANE_ID:-}"

case "$dir" in
  left)  key="ctrl+h" ;;
  down)  key="ctrl+j" ;;
  up)    key="ctrl+k" ;;
  right) key="ctrl+l" ;;
  *) echo "navigate.sh: unknown direction: $dir" >&2; exit 2 ;;
esac

# Foreground process names that mean "Vim is in control of this pane".
# Same matcher vim-tmux-navigator uses: vi, vim, nvim, view, gvim, *diff, ...
vim_re='^g?(view|l?n?vim?x?)(diff)?$'

# Opt-in passthrough for non-Vim TUIs (see README): HERDR_NAV_PASSTHROUGH_RE is an
# ERE matched against the lower-cased process name. Empty (default) forwards only Vim.
passthrough_re="${HERDR_NAV_PASSTHROUGH_RE:-}"

forward=0
if [ "$detect" -eq 1 ] && [ -n "$pane" ] && command -v jq >/dev/null 2>&1; then
  if "$herdr" pane process-info --pane "$pane" 2>/dev/null \
    | jq -e --arg vim "$vim_re" --arg pass "$passthrough_re" \
        '.result.process_info.foreground_processes[]?.name
         | ascii_downcase
         | select(test($vim) or ($pass != "" and (try test($pass) catch false)))' >/dev/null 2>&1; then
    forward=1
  fi
fi

if [ "$forward" -eq 1 ]; then
  exec "$herdr" pane send-keys "$pane" "$key"
fi

# Target the invoking pane; --current is the server's globally focused pane,
# which is not necessarily this one. Without $HERDR_PANE_ID there is nothing to
# name, so fall back to global focus.
if [ -n "$pane" ]; then
  from=(--pane "$pane")
else
  from=(--current)
fi

# --- edge spillover (opt-in: HERDR_NAV_SPILL=1) -----------------------------
# Off by default: pane focus stops dead at the edge of the layout, as before.
# Turned on, the motion carries on into the neighbouring container, i3-style:
#
#   left/right  at the horizontal edge -> previous/next TAB in this workspace
#   up/down     at the vertical edge   -> previous/next WORKSPACE
#
# Both wrap around. After the jump, focus walks to the far side of the new
# layout (crossing rightwards lands on the leftmost pane, and so on) so the
# motion reads as one continuous move.
#
# Needs jq; without it this degrades to plain focus, same as Vim detection above.

plain_focus() { exec "$herdr" pane focus --direction "$dir" "${from[@]}"; }

spill="${HERDR_NAV_SPILL:-}"
[ -n "$spill" ] && [ "$spill" != 0 ] || plain_focus
command -v jq >/dev/null 2>&1 || plain_focus

# Just try the move. The reply says whether focus actually changed and carries
# the tab/workspace it happened in, so there is nothing to probe beforehand.
moved=$("$herdr" pane focus --direction "$dir" "${from[@]}" 2>/dev/null) || exit 0
[ "$(jq -r '.result.focus.changed' <<<"$moved")" = false ] || exit 0

# At the edge. Pick the container to jump to, wrapping at either end.
case "$dir" in
  left)  scope=tab;       step=-1; land=right ;;
  right) scope=tab;       step=1;  land=left  ;;
  up)    scope=workspace; step=-1; land=down  ;;
  down)  scope=workspace; step=1;  land=up    ;;
esac

workspace_id=$(jq -r '.result.focus.layout.workspace_id' <<<"$moved")
tab_id=$(jq -r '.result.focus.layout.tab_id' <<<"$moved")

# Step through the list in the order herdr returns it: that is the on-screen
# order. Do NOT index by .number -- for tabs that is an id, not a position: it
# stays put when a tab is reordered, and closing a tab leaves a hole in the
# sequence (workspace numbers do get compacted, but list order is right there).
# Returns empty when there is nowhere to go (a single tab / workspace), a no-op.
if [ "$scope" = tab ]; then
  target=$("$herdr" tab list 2>/dev/null | jq -r --arg ws "$workspace_id" \
    --arg cur "$tab_id" --argjson step "$step" '
      [ .result.tabs[] | select(.workspace_id == $ws) ] as $list
      | ($list | map(.tab_id) | index($cur)) as $i
      | if ($list | length) < 2 or $i == null then empty
        else $list[(($i + $step) % ($list | length) + ($list | length)) % ($list | length)].tab_id
        end') || exit 0
else
  target=$("$herdr" workspace list 2>/dev/null | jq -r --arg cur "$workspace_id" \
    --argjson step "$step" '
      .result.workspaces as $list
      | ($list | map(.workspace_id) | index($cur)) as $i
      | if ($list | length) < 2 or $i == null then empty
        else $list[(($i + $step) % ($list | length) + ($list | length)) % ($list | length)].workspace_id
        end') || exit 0
fi

[ -n "$target" ] || exit 0

"$herdr" "$scope" focus "$target" >/dev/null || exit 0

# Walk to the far side of the layout we just entered, one pane at a time, until
# nothing moves. --current is deliberate here, unlike above: the tab/workspace
# focus landed us on a pane in the new container, and that is what we walk from
# -- the invoking pane is back in the container we just left.
# Bounded so a layout that always reports a move cannot spin.
for _ in {1..32}; do
  [ "$("$herdr" pane focus --direction "$land" --current 2>/dev/null \
       | jq -r '.result.focus.changed')" = true ] || break
done
