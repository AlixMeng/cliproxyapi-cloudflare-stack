---
name: grok-register-cpa-deploy
description: Deploy the grokRegister-cpa stack end-to-end — auto-register Grok accounts via a Cloudflare temp-email worker, exchange SSO→OAuth via device-flow, ingest credentials into CLIProxyAPI (CPA) for hot-reload, and expose CPA over HTTPS through a Cloudflare Tunnel. Use when the user wants to reproduce grokRegister-cpa, batch-register Grok accounts into a CPA pool, or serve a Grok-compatible OpenAI API from self-hosted OAuth credentials.
---

# Deploy grokRegister-cpa (Grok auto-register → CPA → Grok API)

End-to-end deployment of [Git-creat7/grokRegister-cpa](https://github.com/Git-creat7/grokRegister-cpa) on an Azure VM + Cloudflare. Registers Grok accounts automatically, ingests their OAuth tokens into [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI), and exposes a Grok-compatible OpenAI API.

> **Sanitized template.** Every `<placeholder>` below must be filled with your own values. No secrets are included.

## Architecture (3 components)

```
[Cloudflare]  domain <your-domain> → Email Routing catch-all → Worker <worker-name> → D1 (stores verification emails)
[VM]          CLIProxyAPI on :8317, auth-dir hot-reloads xai-*.json (the account pool)
[Local Mac]   grok_register_ttk.py drives HEADED Chrome → passes Turnstile → SSO → device-flow → writes xai-*.json → scp to VM
(optional)    Cloudflare Tunnel: https://<api-subdomain>.<your-domain> → VM:8317 (HTTPS front for CPA, since NSG blocks :8317)
```

## Prerequisites
- A **Cloudflare** zone with Email Routing enabled (MX → cloudflare), and a credential that has **Email Routing Rules: Edit** (a Global API Key, or an API token scoped `Zone → Email Routing Rules → Edit`). A token with only Workers/D1/Zone-read is NOT enough — it returns `10000 Authentication error` on the catch-all rule.
- A **Linux VM** (Ubuntu 24.04 tested) reachable over SSH, passwordless sudo, in a region close to x.ai (US East works; x.ai/auth.x.ai reachable direct, no proxy).
- A **local Mac** (or any machine with a real display) to run the register — **headed Chrome is required** (see Gotcha #2). The VM cannot run the register (headless fails the second Turnstile).
- `python3` (3.12/3.13 recommended), Cloudflare `wrangler` (or the CF REST API), `gh`, `git`.

## Phase 1 — Cloudflare temp-email Worker (receives Grok verification codes)

1. Clone [dreamhunter2333/cloudflare_temp_email](https://github.com/dreamhunter2333/cloudflare_temp_email); `cd worker && pnpm install`.
2. Create a D1 database `tempmail-db`; record its `<d1-database-id>`.
   - If `wrangler d1 create` times out (e.g. behind a 30s-limited credential runner), use the D1 REST API: `POST https://api.cloudflare.com/client/v4/accounts/<cf-account-id>/d1/database`.
3. Initialize the schema (`db/schema.sql`). The REST `/query` endpoint accepts the **whole multi-statement SQL in one `{"sql": ...}` POST** (returns one result-group per statement).
4. Write `wrangler.toml` (see `templates/wrangler.toml.template`): `PREFIX`, `DOMAINS=["<your-domain>"]`, `DEFAULT_DOMAINS`, `ADMIN_PASSWORDS=["<admin-password>"]`, `JWT_SECRET="<jwt-secret>"`, `ENABLE_USER_CREATE_EMAIL=true`, and the D1 binding.
5. Deploy: `wrangler deploy`. Record the worker URL `https://<worker-name>.<workers-subdomain>.workers.dev`.
6. **Email Routing catch-all** → the worker. `PUT /zones/<cf-zone-id>/email/routing/rules/catch_all` with `{"matchers":[{"type":"all"}],"actions":[{"type":"worker","value":["<worker-name>"]}],"enabled":true}`. **This is the step that needs Email Routing Rules:Edit.**
7. Smoke-test: `POST /api/new_address {"name":"smoke","domain":"<your-domain>"}` → returns `{address, jwt}`; `POST /admin/new_address` with header `x-admin-auth: <admin-password>` also works.

## Phase 2 — CPA on the VM (the Grok API gateway)

1. Run the installer:
   `curl -fsSL https://raw.githubusercontent.com/router-for-me/cliproxyapi-installer/refs/heads/master/cliproxyapi-installer | bash`
   Installs to `~/cliproxyapi/`, auto-generates an `sk-...` API key in `config.yaml`, `auth-dir: ~/.cli-proxy-api`, port `8317`.
2. Record the generated `<cpa-api-key>` from `~/cliproxyapi/config.yaml`. The auth directory is `~/.cli-proxy-api` (the register writes `xai-*.json` here; CPA hot-reloads).
3. `systemctl --user enable --now cliproxyapi.service` (+ `loginctl enable-linger <user>` so it survives SSH disconnect).
4. Verify: `curl -H "Authorization: Bearer <cpa-api-key>" http://localhost:8317/v1/models` → `{"data":[],...}` (empty pool is a valid 200).

### VM system deps (Ubuntu 24.04)
`sudo apt-get install -y python3-pip python3-venv python3-tk xvfb libnss3 libnspr4 libatk1.0-0t64 libatk-bridge2.0-0t64 libcups2t64 libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 libcairo2 libasound2t64 libatspi2.0-0t64 libdrm2 libxshmfence1 fonts-liberation libvulkan1`
- **Gotcha:** 24.04 renamed `libpango1.0-0` → `libpango-1.0-0`. A wrong package name aborts the whole apt transaction.
- Chrome: `wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb && sudo dpkg -i /tmp/chrome.deb || sudo apt-get -f install -y`.

## Phase 3 — Register environment

1. Clone grokRegister-cpa; `python3 -m venv .venv`.
2. **Gotcha:** `requirements.txt` pins `DrissionPage==4.1.1.2`, which is **yanked** on PyPI. Bump to `4.1.1.4` (or latest 4.1.1.x) before `pip install -r requirements.txt`.
3. **Gotcha:** the script does `import tkinter` at module top even in CLI mode → install `python3-tk` (brew users: `brew install python-tk@<ver>`).

## Phase 4 — config.json wiring
See `templates/config.example.json`. Key fields:
- `email_provider=cloudflare`, `cloudflare_api_base=https://<worker-name>.<workers-subdomain>.workers.dev`, `cloudflare_api_key=<admin-password>`, `cloudflare_auth_mode=x-admin-auth`, `cloudflare_path_accounts=/admin/new_address`, `cloudflare_path_messages=/api/mails`, `defaultDomains=<your-domain>`.
- `cpa_auto_add=true`, `cpa_auth_dir=<local dir>`, `proxy=""` (US East needs no proxy).

## Phase 5 — Register + ingest + verify
1. **Run headed** on the local Mac: `echo start | .venv/bin/python grok_register_ttk.py cli` (a real Chrome window opens). Output: `xai-<email>.json` in `cpa_auth_dir`.
2. Push the credential to the VM: `scp auth_local/xai-*.json <vm-user>@<vm-ip>:.cli-proxy-api/`. CPA hot-loads it.
3. Verify `curl /v1/models` now lists Grok models, then:
   `curl .../v1/chat/completions -d '{"model":"grok-4.5","messages":[{"role":"user","content":"hi"}]}'`.
   **Use `grok-4.5`** — it resolves to the free tier (`grok-4.5-build-free`) and replies. Avoid `grok-3-mini`/`grok-3-mini-fast`: brand-new accounts hit `personal-team-blocked:spending-limit` on those.

### Gotcha #1 — catch-all permission
A Cloudflare API token scoped to Workers/D1/Zone-read cannot create Email Routing rules (read **or** write). Use a Global API Key (headers `X-Auth-Email` + `X-Auth-Key`), or a token that explicitly includes `Zone → Email Routing Rules → Edit`.

### Gotcha #2 — headless Chrome cannot pass the profile-page Turnstile
The grok signup has **two** Cloudflare Turnstile gates. Headless/xvfb Chrome passes the email-page one but stalls on the profile-page one (`token长度=0`, "Turnstile 二次复用失败", reproducible). The `turnstilePatch` extension the code references is not in the repo and has no reliable public source. **Fix: run the register on a machine with a real display (headed Chrome).** Everything else can stay on the VM.

### Gotcha #3 — disposable email domains are blocked
`duckmail.sbs`, `baldur.edu.kg` (and any known temp-mail domain) are rejected at the grok signup form ("页面未前进"). You MUST use your own domain via the CF Email Routing catch-all.

### Gotcha #4 — CPA port 8317 is not publicly reachable
Cloud provider NSGs (Azure) block inbound 8317 by default. Expose CPA via a **Cloudflare Tunnel** instead of opening the port (HTTPS, no inbound port, stable hostname). See `templates/cloudflared-cpa.service.template`.

## Exposing CPA over HTTPS (Cloudflare Tunnel) — optional but recommended
1. Install `cloudflared` on the VM.
2. Create a named tunnel (API or dashboard): `POST /accounts/<cf-account-id>/cfd_tunnel {"name":"cpa","tunnel_secret":"<base64 32 bytes>","config_src":"cloudflare"}` → returns `id` + connector `token`.
3. Set ingress: `PUT /accounts/<cf-account-id>/cfd_tunnel/<id>/configurations` with `ingress:[{hostname:"<api-subdomain>.<your-domain>",service:"http://localhost:8317"},{service:"http_status:404"}]`.
4. DNS: CNAME `<api-subdomain>` → `<id>.cfargotunnel.com` (proxied).
5. Run as systemd: `cloudflared tunnel --no-autoupdate run --token <token>` (see `templates/cloudflared-cpa.service.template`).
6. Point any OpenAI-compatible client (OpenCode, etc.) at `https://<api-subdomain>.<your-domain>/v1` with `<cpa-api-key>`.

## Batch registration
`scripts/batch_register.sh` loops until N successful accounts (each = one headed registration), auto-syncs new `xai-*.json` to the VM, and backs off on consecutive failures (rate-limit detection). On macOS use `gtimeout` (`brew install coreutils`); Linux has `timeout`. Expect ~75–90% per-attempt success (transient UI-state failures) and ~50–75s per account; watch for IP rate-limiting past a few hundred from one IP (rotate residential proxies for true scale).

## Verification (the only authoritative gate)
`grok-4.5` via the public CPA endpoint returns a non-empty reply. Everything else (200s, model lists) only proves connectivity, not that credentials are valid.

## Dead ends (already ruled out — don't retry)
- Scoped CF token for catch-all rules → `10000`.
- `wrangler login` if never logged in → no stored OAuth.
- Browser-automation of the dashboard to set catch-all → fragile / needs a live MCP.
- SMTP probe to verify mail delivery → port 25 blocked (ISP + cloud).
- Disposable temp-mail domains → rejected by grok.
- Headless VM for registration → second Turnstile stalls.
