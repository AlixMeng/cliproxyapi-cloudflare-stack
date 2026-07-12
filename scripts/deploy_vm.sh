#!/usr/bin/env bash
# VM bootstrap: CLIProxyAPI (CPA) + base packages (Ubuntu 24.04).
# The CPA gateway itself needs no browser. Run on the VM as a passwordless-sudo user.
# Safe to re-run.
set -eu

echo "### base packages"
sudo apt-get update -qq
sudo apt-get install -y curl ca-certificates jq

echo "### CLIProxyAPI (CPA)"
if [ ! -x ~/cliproxyapi/cli-proxy-api ]; then
  curl -fsSL https://raw.githubusercontent.com/router-for-me/cliproxyapi-installer/refs/heads/master/cliproxyapi-installer | bash
fi
mkdir -p ~/.cli-proxy-api                 # auth-dir; CPA hot-reloads credential .json files dropped here
sudo loginctl enable-linger "$USER" 2>/dev/null || true
systemctl --user daemon-reload
systemctl --user enable --now cliproxyapi.service
sleep 2
echo "CPA active: $(systemctl --user is-active cliproxyapi.service)"
echo "port 8317:  $(ss -tlnp 2>/dev/null | grep -c 8317)"
echo "--- your CPA API key (~/cliproxyapi/config.yaml, api-keys:) ---"
grep -A3 '^api-keys:' ~/cliproxyapi/config.yaml
echo "auth-dir:    ~/.cli-proxy-api"
