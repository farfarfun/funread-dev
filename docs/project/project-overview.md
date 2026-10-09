# 项目说明

> 固定路径：`docs/project/project-overview.md`
>
> 本文件记录适用于整个项目的重要背景和协作约定，由项目负责人维护。

## 基本信息

- 项目名称：funread
- 项目简介：Legado 阅读源（书源 / 订阅源）的采集、解析与阅读平台。`funread-dev` 是编排仓库，通过 Git 子模块固定各应用版本。
- 项目负责人：farfarfun
- 代码仓库：<https://github.com/farfarfun/funread-dev>

## 应用清单

<!-- project-structure:applications:start -->
| 应用 | 路径 | 技术 Profile | Owner | 用途 |
| --- | --- | --- | --- | --- |
| funread | `apps/funread` | python | engineering | 核心领域库（package 类）：规则引擎、阅读服务层、采集源数据模型与采集管线 |
| funread-api | `apps/funread-api` | python | engineering | 后端服务（service 类）：依赖 funread，对外暴露采集源管理与阅读 HTTP API |
| funread-web | `apps/funread-web` | node | engineering | 前端服务（service 类）：/admin 采集源管理端与 /web 阅读端，运行时反代 /api 到 funread-api |
<!-- project-structure:applications:end -->

`apps/funread-dat` 是数据仓库而非应用，不登记在上表里，原因与影响见
[`project-governance/001-overview.md`](./project-governance/001-overview.md) 的「已知治理偏差」。

## 项目目标

- 把 Legado 生态的书源与订阅源采集、校验、归档成可持续使用的语料。
- 在此基础上提供一套自有的阅读体验：C 端（`/web`）面向手机阅读，B 端（`/admin`）面向采集源运维。
- 规则解析能力自持：书源与订阅源的解析规则由 `funread` 的引擎层实现，不依赖 Legado APP。

## 项目范围

### 范围内

- 书源：搜索 → 书籍详情 → 目录 → 正文 全链路解析与阅读。
- 订阅源：Legado RSS 源解析 + 用户自填标准 feed（RSS 2.0 / Atom）订阅。
- 书架、阅读进度、章节服务端缓存与离线下载。
- 采集管线与采集源运维界面。
- C 端账号体系：注册 / 登录，书架、进度、订阅按 `user_id` 隔离；注册由 `FUNREAD_REGISTER_CODE`
  邀请码控制，未设置该环境变量时注册端点直接返回 403。
- B 端 `/admin` 的单口令鉴权，与 C 端账号体系分开。

### 范围外

- JS 规则求值（`@js:` / `<js>` / `java.*` 宿主桥）——当前一律显式报错，不静默降级。
- `singleUrl` / WebView 型订阅源（约占归档的 61%），不做无头浏览器。
- **公网暴露**。session cookie 是 `secure=False`（局域网纯 http 必须如此），所以即便有了
  账号体系，这套鉴权仍然只适用于局域网。HTTPS、`secure` cookie、口令重置、邮箱验证都不做。
- 浏览器端 Service Worker 离线；离线能力由后端 `reader_chapter_cache` 承担。
  正文缓存 `reader_chapter_cache` 不按 `user_id` 隔离 —— 它是正文缓存而不是个人数据。

## 重要约定

- 项目文件创建前先读取根目录 `.project-structure.json` 和项目结构规范。
- 多应用仓库中的代码必须先归属到应用清单中的一个应用，再按该应用的 profile 放入 `apps/<应用名>/` 内。
- 可独立运行、构建或部署的单元必须登记为应用；跨应用共享代码放入 `packages/`。
- 应用清单以 `.project-structure.json` 为准，以上受管表格由项目结构初始化器同步。
- 代码、测试、脚本、配置、文档、资源和生成物必须放入各自负责的目录。
- 项目文档统一使用中文；代码标识符、命令、文件路径和通用技术术语可以保留英文。
- 所有项目文档和文档资产必须按照项目文档管理规范存放到固定路径。
- 在线文档或外部平台链接不能替代仓库内的规范归档。
- 新文档类型必须先明确 Owner 和固定路径。
- **各 `apps/<name>` 仓库不维护自己的 `docs/`**，跨应用与产品级文档集中在本仓库。
- **子模块提交顺序**：先在应用仓库 commit + push，再回本仓库 `git add apps/<name>` 提交指针。
- **本机 `funsecret` 的 `funread/cache/source/db_url` 指向真实生产 MySQL**，任何本地运行或测试
  必须先 `export FUNREAD_DATABASE_URL=...` 覆盖。详见
  [`project-governance/002-local-development.md`](./project-governance/002-local-development.md)。

## 技术与运行环境

- 主要技术栈：Python 3.12（FastAPI / SQLAlchemy / lxml）、Vue 3 + TypeScript + Naive UI + Vite。
- 依赖与构建：Python 侧 `uv`，前端侧 `pnpm`；跨仓库构建发布由仓库根的 `funbuild build` 统一 fan out。
- 开发环境：本地 SQLite（`FUNREAD_DATABASE_URL=sqlite:///...`），前端 `8811`、后端 `18811`，前端同源反代 `/api`。
- 测试环境：无独立环境，等同开发环境；测试用例一律落在 `tmp_path` 下的临时 SQLite。
- 生产环境：MySQL（地址存于 `funsecret`），进程托管方式尚未定稿，见
  [`project-governance/004-roadmap.md`](./project-governance/004-roadmap.md)。

## 相关文档

- 项目结构索引：`.project-structure.json`
- 项目状态：`docs/project/project-status.yaml`
- 项目治理：`docs/project/project-governance/`
- 产品文档：`docs/product/`
- UI 设计：`docs/design/`
- 技术文档：`docs/development/`（平台架构见 `docs/development/platform-foundation/`）
- 测试文档：`docs/testing/`
- 发布记录：`docs/release/`
- 复盘记录：`docs/retrospective/`

## 更新记录

| 日期 | 修改人 | 变更摘要 |
| --- | --- | --- |
| 2026-10-09 | farfarfun | 建立项目说明，登记三个应用，并把原 `docs/` 的扁平文档迁入规范路径 |
| 2026-10-09 | farfarfun | C 端账号体系（注册 / 登录 / 数据按人隔离）纳入范围内，范围外只保留公网暴露 |
| 2026-10-09 | farfarfun | 移除 `funread.web` 的 NiceGUI 视频页（funflix 遗留脚手架），确认 funread 为 package 类 |
