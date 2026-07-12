#!/usr/bin/env bash
# Batch-register grok accounts with HEADED Chrome and ingest into CPA.
# Run on the machine that has a real display (e.g. your Mac).
#
# Usage:
#   TARGET=10  ./batch_register.sh
#   VM_HOST=user@ip ./batch_register.sh   # scp target (CPA auth-dir)
#
# Requires the register repo cloned next to this script with a working venv
# (DrissionPage==4.1.1.4, curl_cffi, python3-tk). On macOS: `brew install coreutils`
# for gtimeout; on Linux use `timeout`.
set -u
REGISTER_DIR="${REGISTER_DIR:-$HOME/grokRegister-cpa}"
AUTH_DIR="${AUTH_DIR:-$REGISTER_DIR/auth_local}"
VM_HOST="${VM_HOST:-}"                       # e.g. user@1.2.3.4 ; empty = skip scp
TARGET="${TARGET:-10}"
PER_ACCT_TIMEOUT=220
TIMEOUT_BIN="$(command -v gtimeout || command -v timeout)" || { echo "need gtimeout/timeout"; exit 1; }

mkdir -p "$AUTH_DIR"
count() { ls "$AUTH_DIR"/xai-*.json 2>/dev/null | wc -l | tr -d ' '; }

start=$(count); target=$((start + TARGET)); attempt=0; consec=0
echo "=== BATCH start=$start target=$target ($(date -Iseconds)) ==="

while [ "$(count)" -lt "$target" ]; do
  attempt=$((attempt + 1)); cur=$(count)
  echo "--- attempt #$attempt | have=$cur/$target ---"
  (cd "$REGISTER_DIR" && echo start | "$TIMEOUT_BIN" "${PER_ACCT_TIMEOUT}s" .venv/bin/python grok_register_ttk.py cli)
  after=$(count)
  if [ "$after" -gt "$cur" ]; then
    consec=0; echo "[OK] total=$after"
    [ -n "$VM_HOST" ] && rsync -a -e ssh "$AUTH_DIR"/xai-*.json "$VM_HOST":.cli-proxy-api/ && echo "[rsync] -> CPA"
  else
    consec=$((consec + 1)); echo "[FAIL] consec=$consec"
    if [ "$consec" -ge 8 ]; then echo "[THROTTLE] 8 fails — pausing 180s"; sleep 180; consec=0; fi
  fi
done
echo "=== BATCH DONE have=$(count) (target=$target) $(date -Iseconds) ==="
