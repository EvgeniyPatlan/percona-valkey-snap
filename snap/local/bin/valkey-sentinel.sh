#!/bin/bash
set -euo pipefail

# Extra ad-hoc flags: sudo snap set _NAME_ sentinel-args="--loglevel debug"
SNAP_ARGS="$(snapctl get sentinel-args 2>/dev/null || true)"

# valkey-sentinel is a symlink to valkey-server, so --sentinel flag is required.
# The daemon runs as snap_daemon against the snap_daemon-owned copy in $SNAP_DATA.
exec "${SNAP}/usr/bin/setpriv" --clear-groups --reuid snap_daemon --regid snap_daemon -- \
    "${SNAP}/usr/bin/valkey-sentinel" "${SNAP_DATA}/etc/valkey/sentinel.conf" --sentinel ${SNAP_ARGS}
