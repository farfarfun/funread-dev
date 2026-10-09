# 项目治理总览

本文档包收录适用于整个 `funread-dev` 工作区的治理约定：本地开发怎么起环境、发布与进程入口
怎么约定、后续计划做什么不做什么。产品、设计、技术、测试四类文档按功能拆在
`docs/product|design|development|testing/<feature-slug>/` 下，不放在这里。

## 章节目录

| 章节 | 内容 |
| --- | --- |
| [002-local-development.md](./002-local-development.md) | 本地开发环境搭建、运行方式、已踩过的坑与一套可照抄的验证步骤 |
| [003-release-and-entrypoint.md](./003-release-and-entrypoint.md) | 应用分类、CLI Entrypoint Contract、`scripts/setup.sh` 的 action 分组与构建发布链路 |
| [004-roadmap.md](./004-roadmap.md) | 候选任务与「明确不做」的范围边界 |

## 工作区形态

`funread-dev` 是编排仓库（dev repo），本身不放任何应用代码，只记录四个子模块的 commit 指针
加跨仓库的 `scripts/` 与 `docs/`。应用清单见
[`../project-overview.md`](../project-overview.md) 的受管表格。

四个子模块各自是独立 GitHub 仓库，有自己的 git 历史，要单独 commit / push：

| 路径 | 仓库 | 类别 |
| --- | --- | --- |
| `apps/funread` | `farfarfun/funread` | package（核心库） |
| `apps/funread-api` | `farfarfun/funread-api` | service（后端） |
| `apps/funread-web` | `farfarfun/funread-web` | service（前端） |
| `apps/funread-dat` | `farfarfun/funread-dat` | 数据仓库（见下） |

> `funread-cache` **不是** 子模块，也不应该被加回来 —— 它是一个只通过
> `fundrive.GithubDrive`（HTTP API）读写的远程仓库，承载采集产物的静态发布内容，和本工作区
> 里的代码没有本地检出关系。细节见
> [`../../development/platform-foundation/010-funread-cache.md`](../../development/platform-foundation/010-funread-cache.md)。

## 已知治理偏差

### `apps/funread-dat` 未登记进 `.project-structure.json`

`project-structure-governance` 要求 `apps/` 下的每个目录都登记成 `applications` 的一项，而每个
技术 profile 都强制要求应用根下存在源码区域（`python`/`node`/`generic` 都要 `src/`）。
`funread-dat` 的内容是 5 个胶水脚本（`scripts/*.py`）加数据快照（`hubs/`），`pyproject.toml` 里
标了 `[tool.uv] package = false`，**没有也不应该有可导入的源码包**。

两条路都不干净：登记它会因为缺 `apps/funread-dat/src` 产生 `block` 级的
`application.zone_missing`；为了过检查去建一个空的 `src/` 则是造假。

**当前取舍**：不登记，接受 checker 的一条 `revise` 级 `application.unregistered`，并在这里
留档。它的角色由本文档和 `README.md` 的应用表格说明，不靠 manifest 表达。

**消除这条偏差的前提**是先决定 `funread-dat` 的归属：要么把 5 个脚本做成 `src/funread_dat/`
的真实 src-layout 包（调用方式从 `python scripts/xxx.py` 改为模块入口），要么承认它是数据仓库
并把它从 `apps/` 移出去。这是产品/工程归属决策，不是顺手能改的事，因此本轮不动。
