#!/usr/bin/env bash
# Mock herdr binary for testing navigate.sh
# Records invocations to $MOCK_HERDR_LOG so tests can assert on them.
# The exit code and output behaviour is controlled by env vars.

log="${MOCK_HERDR_LOG:-/tmp/mock_herdr.log}"
echo "$*" >> "$log"

# If the call is "pane process-info --current", emit JSON.
if [[ "$1" == "pane" && "$2" == "process-info" && "$3" == "--current" ]]; then
  echo "${MOCK_PROCESS_INFO:-"{}"}"
  exit "${MOCK_PROCESS_INFO_EXIT:-0}"
fi

exit 0
