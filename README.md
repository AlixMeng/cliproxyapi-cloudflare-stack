# grok-register-cpa-deploy

一套**完全脱敏**、可复用的部署 skill，用于复现
[Git-creat7/grokRegister-cpa](https://github.com/Git-creat7/grokRegister-cpa)：

> 自动注册 Grok 账号 → 把 OAuth 凭证入库
> [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)（CPA）→
> 用自己的凭证对外提供 Grok 兼容的 OpenAI API，并通过 HTTPS 暴露。

本仓库**不含任何密钥**。所有需要你填的值都是 `<占位符>`。

## 你能得到什么
- `SKILL.md` —— 完整的端到端部署流程（权威指南）。
- `templates/` —— `wrangler.toml`、注册机 `config.json`、cloudflared 的 systemd
  单元，全部带占位符。
- `scripts/` —— D1 schema 初始化（走 REST API）、VM 一键部署脚本（CPA + Chrome +
  依赖）、批量注册循环脚本。

## 4 个必须记住的核心点（别跳过）
1. **Email Routing catch-all** 需要一个有 `Email Routing Rules: Edit` 权限的
   Cloudflare 凭据。只有 Workers/D1 权限的 token 会返回 `10000`。用 Global API Key，
   或者显式带 `Email Routing Rules: Edit` 的 token。
2. **注册必须跑「有头」Chrome**（真实显示器）。headless / xvfb 的 Chrome 会卡在
   grok 的第二个 Turnstile，而且代码引用的 `turnstilePatch` 扩展无公开可用版本。
   所以注册机放在本地 Mac 跑，再把 `xai-*.json` scp 到 VM 的 CPA auth-dir。
3. **`DrissionPage==4.1.1.2` 已被 yank**（PyPI 下架）→ 改用 `4.1.1.4`。脚本还会
   无条件 `import tkinter` → 装 `python3-tk`。
4. **CPA 的 8317 端口被云厂商 NSG 挡住** → 用 Cloudflare Tunnel 反代出 HTTPS
   （无需开放入站端口）。调用时用 `grok-4.5`（走免费额度）；新号用
   `grok-3-mini*` 会触发 spending-limit。

完整流程、坑点和已验证的死胡同，详见 `SKILL.md`。

## 验收标准（唯一权威判据）
经过你自己的 CPA 公开端点，`grok-4.5` 返回**非空回复**。只有这一条能证明整条链路真的
打通了——其它（200、模型列表）只代表连通，不代表凭证有效。

## 目录结构
```
SKILL.md                                        # 部署 skill 主体
README.md
.gitignore                                      # 防止误提交 key / config / 账号
templates/wrangler.toml.template                # 邮箱 Worker 配置（占位符）
templates/config.example.json                   # 注册机 config（占位符）
templates/cloudflared-cpa.service.template      # cloudflared systemd 单元
scripts/init_d1_schema.py                       # D1 schema 初始化（REST API 版）
scripts/deploy_vm.sh                            # VM 一键装 CPA + Chrome + 依赖
scripts/batch_register.sh                       # 批量注册循环（自动 rsync + 限流退避）
```

## License
MIT —— 仅用于在你自有基础设施上做教育 / 授权用途的部署。请遵守 x.ai 与 Cloudflare 的
服务条款。
