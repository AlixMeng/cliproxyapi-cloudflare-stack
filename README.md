# grok-register-cpa-deploy

A reusable, **fully sanitized** deployment skill for reproducing
[Git-creat7/grokRegister-cpa](https://github.com/Git-creat7/grokRegister-cpa):

> Auto-register Grok accounts → ingest their OAuth tokens into
> [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) (CPA) →
> serve a Grok-compatible OpenAI API from your own credentials, exposed over HTTPS.

This repo contains **no secrets**. Every value you need to provide is a `<placeholder>`.

## What you get
- `SKILL.md` — the complete end-to-end procedure (the authoritative guide).
- `templates/` — `wrangler.toml`, the register `config.json`, and the cloudflared
  systemd unit, all with placeholders.
- `scripts/` — D1 schema init (REST API), VM bootstrap (CPA + Chrome + deps), and a
  batch-registration loop.

## The 4 load-bearing facts (don't skip)
1. **Email Routing catch-all** needs a Cloudflare credential with
   `Email Routing Rules: Edit`. A Workers/D1-only token returns `10000`. Use a Global
   API Key or an explicitly-scoped token.
2. **Registration must run HEADED** (real display). Headless/xvfb Chrome stalls on the
   second grok Turnstile, and the `turnstilePatch` extension is unavailable. Run the
   register on your Mac, then `scp` the `xai-*.json` into the VM's CPA auth-dir.
3. **`DrissionPage==4.1.1.2` is yanked** on PyPI → use `4.1.1.4`. The script also
   `import tkinter` unconditionally → install `python3-tk`.
4. **CPA port 8317 is NSG-blocked** → front it with a Cloudflare Tunnel (HTTPS, no
   inbound port). Call `grok-4.5` (free tier); `grok-3-mini*` hits a spending limit on
   fresh accounts.

See `SKILL.md` for the full walkthrough, gotchas, and verified dead-ends.

## Verification gate
`grok-4.5` through your public CPA endpoint returns a non-empty reply. That, and only
that, proves the stack works end-to-end.

## License
MIT — for educational/authorized-use deployment of your own infrastructure. Respect
x.ai's Terms and Cloudflare's Terms where applicable.
