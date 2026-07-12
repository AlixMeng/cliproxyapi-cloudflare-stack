#!/usr/bin/env bash
# VM bootstrap: CLIProxyAPI + Chrome + system deps (Ubuntu 24.04).
# Run on the VM as a passwordless-sudo user. Safe to re-run.
set -eu

echo "### system deps (24.04 package names)"
sudo apt-get update -qq
sudo apt-get install -y \
  python3-pip python3-venv python3-dev python3-tk \
  xvfb libnss3 libnspr4 libatk1.0-0t64 libatk-bridge2.0-0t64 libcups2t64 \
  libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 \
  libpango-1.0-0 libcairo2 libasound2t64 libatspi2.0-0t64 libdrm2 libxshmfence1 \
  fonts-liberation libu2f-udev libvulkan1 xdg-utils unzip jq

echo "### Chrome stable"
wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
sudo dpkg -i /tmp/chrome.deb || sudo apt-get -f install -y
google-chrome --version

echo "### CLIProxyAPI (CPA)"
if [ ! -x ~/cliproxyapi/cli-proxy-api ]; then
  curl -fsSL https://raw.githubusercontent.com/router-for-me/cliproxyapi-installer/refs/heads/master/cliproxyapi-installer | bash
fi
# auth-dir + linger + service
mkdir -p ~/.cli-proxy-api
sudo loginctl enable-linger "$USER" 2>/dev/null || true
systemctl --user daemon-reload
systemctl --user enable --now cliproxyapi.service
sleep 2
echo "CPA active: $(systemctl --user is-active cliproxyapi.service)"
echo "port 8317: $(ss -tlnp 2>/dev/null | grep -c 8317)"
echo "--- your CPA API key (from ~/cliproxyapi/config.yaml, api-keys:) ---"
grep -A3 '^api-keys:' ~/cliproxyapi/config.yaml
echo "auth-dir: ~/.cli-proxy-api"
