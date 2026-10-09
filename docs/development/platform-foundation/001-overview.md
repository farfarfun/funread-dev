# 平台底座架构总览

本文档包是 funread 平台底座的架构设计：采集管线、数据层、采集源管理 API 与管理前端。
内容由原 `docs/architecture.md` 原样迁入并按原有的 11 节拆章，**动手改代码前必读**。

按功能划分的设计文档不在这里：

- 阅读端（规则引擎、阅读服务层、C 端界面）见 `docs/development/reader-client/`。
- 订阅源（RSS 引擎、订阅管理）见 `docs/development/rss-subscription/`。
- 本地环境、发布与进程入口约定见 `docs/project/project-governance/`。

## 章节目录

| 章节 | 内容 |
| --- | --- |
| [002-what-this-project-does.md](./002-what-this-project-does.md) | 项目在做什么、这套改造要解决的问题、范围边界 |
| [003-repository-map.md](./003-repository-map.md) | 仓库与模块地图：每个目录放什么 |
| [004-data-flow.md](./004-data-flow.md) | 采集管线的数据流与各段开关 |
| [005-database-design.md](./005-database-design.md) | 三张采集表的设计与 schema 迁移历史 |
| [006-database-url-resolution.md](./006-database-url-resolution.md) | `resolve_database_url()` 的三层优先级与 SQLite PRAGMA 调优 |
| [007-source-type-registry.md](./007-source-type-registry.md) | `sources/factory.py` 的采集源注册表与扩展方式 |
| [008-sqlite-backup.md](./008-sqlite-backup.md) | SQLite 一致性备份到 `funread-dat/hubs/db/bak/` |
| [009-source-management-api.md](./009-source-management-api.md) | `funread-api` 的模块划分、异常映射与鉴权取舍 |
| [010-web-frontend.md](./010-web-frontend.md) | `funread-web` 的结构、端口约定与同源反代 |
| [011-funread-cache.md](./011-funread-cache.md) | `funread-cache` 的角色，以及为什么它不是 submodule |
| [012-known-tech-debt.md](./012-known-tech-debt.md) | 已知技术债与限制 |
| [013-reference-implementations.md](./013-reference-implementations.md) | 上游、竞品与「做 APP vs 做 Web」的定位差别 |

## 一句话概括

`funread` 管理 [Legado 阅读 APP](https://github.com/gedoor/legado) 用的书源（booksource）和
RSS 源（rsssource）：从第三方「源列表 URL」下载、按站点归档去重、探活校验、（可选）LLM 合并
候选版本、写回数据库并生成快照发布。在此之上，`funread` 自带规则引擎与阅读服务层，
`funread-api` 把能力暴露成 HTTP API，`funread-web` 提供 `/admin` 运维端与 `/web` 阅读端。
