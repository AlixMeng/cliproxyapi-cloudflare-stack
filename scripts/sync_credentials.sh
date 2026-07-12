#!/usr/bin/env bash
# Sync credential files (e.g. xai-*.json) from a local dir into a CLIProxyAPI
# auth-dir on a remote host. CPA hot-reloads them automatically.
#
# Usage:
#   SRC=./auth_local  VM_HOST=user@1.2.3.4  ./sync_credentials.sh
#
# Only syncs files you are authorized to use. This script does not create or
# register accounts — it only copies existing credential files you provide.
set -u
SRC="${SRC:-./auth_local}"
VM_HOST="${VM_HOST:?set VM_HOST=user@host}"
REMOTE_DIR="${REMOTE_DIR:-.cli-proxy-api}"

mkdir -p "$SRC"
if ! ls "$SRC"/*.json >/dev/null 2>&1; then
  echo "no .json credential files in $SRC — nothing to sync"; exit 0
fi
echo "syncing $SRC/*.json -> $VM_HOST:$REMOTE_DIR/"
rsync -a -e ssh "$SRC"/*.json "$VM_HOST:$REMOTE_DIR/"
echo "done. Verify on the host: curl -H \"Authorization: Bearer \$CPA_KEY\" http://localhost:8317/v1/models"
