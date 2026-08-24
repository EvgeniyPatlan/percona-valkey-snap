#!/bin/bash
set -euo pipefail

# Extra ad-hoc flags: sudo snap set _NAME_ valkey-args="--loglevel debug"
SNAP_ARGS="$(snapctl get valkey-args 2>/dev/null || true)"

# valkey-server rewrites its own config (CONFIG REWRITE), so it runs as
# snap_daemon against the snap_daemon-owned copy in $SNAP_DATA.
exec "${SNAP}/usr/bin/setpriv" --clear-groups --reuid snap_daemon --regid snap_daemon -- \
    "${SNAP}/usr/bin/valkey-server" "${SNAP_DATA}/etc/valkey/valkey.conf" ${SNAP_ARGS}
