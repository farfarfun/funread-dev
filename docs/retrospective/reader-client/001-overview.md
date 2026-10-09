# 阅读端复盘

覆盖 M3a–M3d 与 M3c（治理底座、Entrypoint Contract、账号体系、C 端界面）。

## 1. 范围

交付了 `/web` 阅读端的完整链路：搜索→详情→目录→正文、书架与阅读进度、离线下载、
账号体系与数据按人隔离；以及支撑它的治理底座与两个 service 应用的 CLI 契约。

## 2. 目标与结果回顾

| 目标 | 结果 |
| --- | --- |
| C 端前后端接口与界面都做出来，功能罗列清楚 | 达成。功能清单落在 `docs/product/reader-client/002-feature-list.md`，33 项带交付级别 |
| 符合两套 skill 规范 | 基本达成。结构 checker 剩一条 `revise`（`apps/funread-dat`），原因与消除前提已留档 |
| 加登录注册模块 | 达成。真多用户、数据按人隔离、邀请码控制注册 |
| 测试覆盖 | funread 619 / funread-api 131 / funread-web 38，全过 |

## 3. 时间线

| 日期 | 事件 |
| --- | --- |
| 2026-10-07 | M1 规则引擎 |
| 2026-10-08 | M2 阅读服务层与 API |
| 2026-10-09 | M3a 治理底座；发现远端有 15 个未合并 commit，合并；M3b CLI 契约；M3d 账号体系；M3c C 端界面 |

## 4. 做对的

**先梳理再动手，而且梳理靠实测。** 「订阅源的缺口在 `SourceSpec` 而不是数据层」
这个结论是读代码加跑数据得出的，不是猜的。如果按最初的假设直接写 `engine/rss.py`，
会在候选池永远为空上卡很久。

**把「失败」当成主要交互路径。** 源语料大面积失效是这个产品的基本事实，所以
搜索的三种空态、422/502 的区分、`last_error` 的显示，都不是边角打磨而是核心体验。

**分层禁令由测试强制。** `engine/` 不许 import funsecret —— 一条 import 链就会连上
生产 MySQL。这条由 `test_no_heavy_imports.py` 看着，加了两个新模块后依然成立。

## 5. 问题与根因

### 问题一：差点把生产库保护弄丢

合并远端 master 时，远端把三个任务入口改回了直读 funsecret，绕过
`FUNREAD_DATABASE_URL`。而本机 funsecret 存的是生产 MySQL —— 本地跑一次探活就会
写进去。

**根因**：两边并行开发，而「必须走 `resolve_database_url()`」这个约束只写在代码
注释里，没有测试守着。注释在合并冲突中很容易被当成「风格差异」丢掉。

### 问题二：隐式本地身份差点打开书架

`require_user` 的第一版只要求「还没有账号」就授予隐式身份。一个原本靠
`FUNREAD_API_PASSWORD` 锁住一切的部署，升级后书架会对局域网敞开。

**根因**：加账号体系时只想了「新装用户要能直接用」，没想「已有部署升级后会怎样」。
这是加功能时的典型盲区 —— 只测了 greenfield 路径。

### 问题三：PID 文件跟着 cwd 走

远端的 CLI 把 PID 文件写在 `Path.cwd() / ".run"`。换目录执行 `server stop` 会报
「未在运行」然后静默返回，而进程还活着。

**根因**：`.run/` 这个约定在仓库根下是对的，但 CLI 装成全局命令后可以从任何目录
调用，这时 cwd 就是任意的。

### 问题四：`status: todo` 让台账 BLOCK

checker 的 `PLACEHOLDERS` 包含 `todo`，报错说「缺少 name、owner、due 或 status」——
字段其实填了，是值被当成占位符。照报错去补字段永远修不好。

**根因**：外部工具的报错信息指错了方向。只能靠读它的源码。

## 6. 数据与证据

见 [`docs/testing/reader-client/test-report/001-overview.md`](../../testing/reader-client/test-report/001-overview.md)。

## 7. 改进动作

| 动作 | Owner | 截止 | 状态 |
| --- | --- | --- | --- |
| 给「任务入口必须走 `resolve_database_url()`」加一条测试，不只靠注释 | farfarfun | 2026-10-16 | 待做 |
| 加功能时同时测 greenfield 与 upgrade 两条路径（已在账号体系上补齐，形成习惯） | farfarfun | 2026-10-16 | 进行中 |
| `funread-dat` 的归属定下来，消掉那条 `revise` | farfarfun | 2026-10-31 | 待做 |
| 真机走查（安全区、虚拟滚动帧率、飞行模式离线） | farfarfun | 2026-10-16 | 待做 |
| `builder.py` 的 49 个 star-import 独立清理一次（带测试） | farfarfun | 2026-11-15 | 待做 |

## 8. 后续结论

阅读端这条链可用了，但有两件事决定它能走多远：

1. **真机验证还没做。** 安全区、`100dvh`、虚拟滚动帧率这些只能实机过，DevTools
   的视口模拟替代不了。这是交付完整性上最大的一个空缺。
2. **源可用性是产品天花板。** 书源 ~63%、订阅源 10.6% 的纯 Python 可解析率，决定
   了「搜不到」会是常态。接 quickjs 能把这两个数字推到 ~95% 和 ~38%，是下一轮最
   有价值的单项投入。

发布顺序上还有一个硬约束：`funread-api` 依赖 `funread[reader]`，而索引上的
funread 1.1.103 没有这个 extra。必须从仓库根跑一次 `funbuild build` 让两者以同一个
共享版本号一起发布，单独发 funread-api 会装出一个 import 就崩的 CLI。
