# 参考实现与竞品

这一章只记**是什么、可以从它那里看什么**，不做结论 —— 真正的对比分析要读过代码
之后再写，到时候各开一节。

## 上游与规则来源

| 项目 | 角色 |
| --- | --- |
| [gedoor/legado](https://github.com/gedoor/legado) | Legado 阅读 APP 本体（Android / Kotlin）。书源与订阅源的**规则语言定义方** —— `funread/legado/engine/` 的一切语义以它为准 |
| [规则说明](https://alanskycn.gitee.io/teachme/) | 社区维护的规则文档。写引擎时的第一手参考 |
| [hectorqin/reader](https://github.com/hectorqin/reader) | Legado 的第三方服务端（Kotlin）。和 funread 定位最接近的一个：都是「把 Legado 的规则搬到服务端 + 提供 Web 阅读界面」 |

## 待分析的分支与竞品

用户 2026-10-09 提供，尚未逐一阅读。

| 项目 | 初步判断 | 想从它那里看什么 |
| --- | --- | --- |
| [HapeLee/legado-with-MD3](https://github.com/HapeLee/legado-with-MD3) | Legado 的 Material Design 3 改版分支 | **界面与交互**。它是原生 APP 的现代化重做，而 funread 的 `/web` 是移动 Web —— 阅读页的手势分区、设置面板的组织方式、书架的信息密度都值得对照。我们当前的取舍写在 [`docs/design/reader-client/`](../../design/reader-client/001-overview.md) |
| [LegadoTeam/legado](https://github.com/LegadoTeam/legado) | 团队维护的 Legado 分支 | **规则语言的演进**。如果它在上游之外扩了规则语法或字段，`engine/source.py` 的归一化表可能要跟着认。另外它对 JS 规则的宿主 API（`java.*`）实现是接 quickjs 时的直接参考 |
| [Luoyacheng/legado-E](https://github.com/Luoyacheng/legado-E) | 另一个 Legado 分支（命名看不出重点） | 待定。先看 README 与 commit 历史判断它改了哪一层 |

## 对比时最该看的四件事

funread 当前最薄弱、最需要外部参考的地方，按价值排序：

1. **JS 规则求值。** 书源可解析率 ~63%、订阅源 10.6% 的天花板全在这里。Legado 本体
   用 Rhino/QuickJS 并实现了一整套 `java.*` 宿主 API（`java.ajax`、`java.getCookie`、
   `java.cache`…）。需要的是那份**宿主 API 的完整清单与语义**，而不是实现细节 ——
   我们要在 Python 侧重建它。见 [`012-known-tech-debt.md`](./012-known-tech-debt.md)。

2. **源可用性的判定与排序。** 实测 150 个标着可用的书源里只有 6 个真能跑通四段
   流程。funread 的做法是「实跑成功过的排最前」（`list_source_prefs` 的 ORDER BY）。
   原生 APP 有没有更好的信号（校验流程、超时策略、失败衰减）值得看。

3. **换源的章节定位。** funread 现在按章节名精确→归一化→按比例估
   （`reader/matching.py`）。Legado 本体在这件事上有多年的真实反馈，它的匹配策略
   可能更稳。

4. **`singleUrl` / WebView 型源。** 占订阅源归档 21.7%。原生 APP 有 WebView 可用，
   所以它能支持；服务端要支持就得接无头浏览器。看它怎么界定「哪些源必须走
   WebView」，可以反推我们的拒绝条件准不准。

## 和 funread 的定位差别

**最大的区别就一条：它们做 APP，funread 做 Web。** 而且 funread 的 Web 要同时
覆盖两种形态 —— 手机浏览器访问是主场景，**PC 也必须支持**，不是「顺带能用」。

这一条决定了对比时哪些能抄、哪些不能：

### 它们有的，我们没有

| 它们（原生 APP） | funread（Web） | 后果 |
| --- | --- | --- |
| WebView | 无 | `singleUrl` 型源（订阅源归档的 21.7%）它们能支持，我们只能显式拒绝 |
| 本地文件系统 | 服务端存储 | 「离线」的语义不同：它们是真离线，我们是「正文已抓到服务端」，仍需连得上服务端 |
| 一个用户一台设备 | 多用户、数据按人隔离 | 它们的数据层是设备本地 Room；我们是服务端 SQLite/MySQL + `user_id` 隔离。**架构不能照搬** |
| 系统级手势与返回键 | 浏览器的历史栈 | 返回行为要自己兜（`TopBar` 的 `goBack` 会在没有 history 时回 fallback） |

### 我们有的，它们没有

| funread（Web） | 后果 |
| --- | --- |
| 一个 URL 就能分享 / 刷新回到原处 | 所以 `GET /rss/article` 刻意保持 GET —— 刷新能回到同一篇 |
| 不用安装、不用分发、不受应用商店约束 | 改一次所有设备同时生效 |
| **同一套界面要同时服务手机与 PC** | 这是最大的额外约束，见下 |

### PC 也要支持，这是它们不需要考虑的

原生 APP 只需要为一种形态做设计；funread 的 `/web` 要在手机竖屏和桌面宽屏上
**都好用**。几处必然不同的地方：

- **翻章交互。** 手机靠左右边缘点击，PC 应该靠键盘（←/→）和明确的按钮 ——
  在 2560px 宽的屏幕上，左右各 25% 的「触控带」是 640px 的死区，非常反直觉。
- **导航布局。** 底部 TabBar 是移动端惯例；桌面宽屏上横跨整个屏幕的底栏不合常规。
- **内容宽度。** 列表与网格在宽屏上不能无限铺开 —— 书架网格会变成二十列小方块。
- **指针 vs 触控。** hover 态只在 PC 有意义；44px 最小触控区只在触屏必要。

当前实现是**手机优先**的，桌面端的这几处还没专门处理 —— 记在
[`docs/project/project-status.yaml`](../../project/project-status.yaml) 里作为待办。
