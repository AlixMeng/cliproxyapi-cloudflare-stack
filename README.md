# cliproxyapi-cloudflare-stack

一套**自托管 LLM API 网关**的部署模板：用 [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)
（CPA）+ Cloudflare（Workers + D1 + Email Routing + Tunnel）搭一个你自己的、OpenAI 兼容的
API 网关，凭证通过文件热加载进 CPA，对外走 HTTPS。

> ## ⚠️ 免责声明（必读）
> 本项目**仅用于学习 Cloudflare 与 CLIProxyAPI 的部署架构**，以及在你**已合法获得授权**的
> 前提下管理你**自己**的账号凭证。
>
> **严禁**用于：自动化批量注册账号、绕过任何平台的人机验证/反爬机制、规避访问控制、或违反任何
> 第三方（包括但不限于 x.ai、Cloudflare）的服务条款。
>
> 使用者需自行确保合法合规并自行承担全部法律责任。本项目按「现状」提供，**不提供任何担保**，
> 作者不对任何滥用后果负责。如收到权利人投诉，仓库可能随时删除。

---

## 它实际解决了什么（合法部分）
- 用 **Cloudflare Workers + D1** 搭一个可程序化收信的邮箱端点（自己的域名）。
- 用 **CLIProxyAPI** 把多份凭证组成一个池，对外暴露统一的 OpenAI 兼容 API，自带热加载与故障转移。
- 用 **Cloudflare Tunnel** 把内网服务安全地反代成 HTTPS 公网域名（无需开放入站端口、无需公网 IP）。

这三块都是标准的自托管 / Cloudflare 基础设施实践，与具体上游模型无关。

## 仓库内容
```
SKILL.md                                   # 部署流程（重心在 Cloudflare + CPA 基础设施）
README.md
.gitignore                                 # 防止误提交 key / config / 凭证
templates/wrangler.toml.template           # 收信 Worker 配置（占位符）
templates/config.example.json              # CPA 凭证对接配置（占位符）
templates/cloudflared-cpa.service.template # cloudflared systemd 单元
scripts/init_d1_schema.py                  # D1 schema 初始化（REST API 版）
scripts/deploy_vm.sh                       # VM 一键装 CPA + Chrome 运行时 + 依赖
scripts/sync_credentials.sh                # 把本地凭证文件同步进 CPA auth-dir（rsync）
```

## 核心技术点
1. **Cloudflare Email Routing catch-all** 需要 `Email Routing Rules: Edit` 权限。只有
   Workers/D1 权限的 token 会返回 `10000`——用 Global API Key 或显式带该权限的 token。
2. **CPA 端口（8317）通常被云厂商 NSG 挡住** → 用 Cloudflare Tunnel 反代出 HTTPS，
   而不是开公网入站口。
3. **`wrangler` 受限于 30s 超时环境时**，D1 建库/初始化可改走 REST API（一次 POST
   多语句）。
4. Ubuntu 24.04 包名变化：`libpango1.0-0` → `libpango-1.0-0`；脚本若 `import tkinter`
   需装 `python3-tk`。

## 关于「凭证从哪来」
本项目**不提供、也不指导**任何自动注册或绕验证手段。`config.example.json` 里的凭证字段，
由你**通过合规渠道自行取得并填入**。上游 [grokRegister-cpa](https://github.com/Git-creat7/grokRegister-cpa)
是第三方项目，是否使用、是否合规，由你自行判断并担责——本项目不背书其任何用法。

## License
MIT —— 仅用于教育 / 授权用途的自托管基础设施部署。
