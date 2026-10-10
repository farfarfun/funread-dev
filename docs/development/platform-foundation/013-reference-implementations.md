# 参考实现与竞品

这一章记**是什么、可以从它那里看什么**，外加一份逐项的功能对照。

界面参照的「差别」小节与功能对照表的核对日期是 **2026-10-10**（对照的是
`apps/funread-web` 的当前源码，不是计划）。改了界面就要回来重核 —— 这几节在
2026-10-10 之前整体过期过一次，差别写的还是补齐之前的状态。

## 上游与规则来源

| 项目 | 角色 |
| --- | --- |
| [gedoor/legado](https://github.com/gedoor/legado) | Legado 阅读 APP 本体（Android / Kotlin）。书源与订阅源的**规则语言定义方** —— `funread/legado/engine/` 的一切语义以它为准。功能上限的参照系 |
| [规则说明](https://alanskycn.gitee.io/teachme/) | 社区维护的规则文档。写引擎时的第一手参考 |

## 同类的服务端实现（直接竞品）

两个都是「把 Legado 的规则搬到服务端 + 提供 Web 阅读界面」，和 funread 同一条赛道。

| 项目 | 栈 | 状态 |
| --- | --- | --- |
| [tthking/reader-dev](https://github.com/tthking/reader-dev) | Rust + Vue 3，主线 v5.2.4（legacy 分支留着 Kotlin 的 v4.0.7） | **当前真正的直接竞品**，2026 年仍在迭代。有 OPDS、WebDAV、本地书仓、书源调试器（SSE 流式输出搜索/目录/正文的逐条规则日志）、换源抽屉里显示源作者与各源章节末尾预览 |
| [hectorqin/reader](https://github.com/hectorqin/reader) | Kotlin + Spring Boot + Vert.x，Vue + Element | **已停更**：完整源码只开到 v2.5.4，之后转为部分开源（`hectorqin/reader-legado`），官方 Demo 已关停。有 WebDAV、听书、多用户（`USERLIMIT` 默认与上限 50）、章节缓存、自定义 CSS，并靠配套的 `hectorqin/remote-webview` 容器支持 WebView 型源 |

> 这一节以前把 hectorqin/reader 写成「和 funread 定位最接近的一个」。那是对的，但
> 它已经不是活的参照了 —— 找现成答案应该先看 reader-dev。

## 主要界面参照：CCSSNE/legado

[CCSSNE/legado](https://github.com/CCSSNE/legado) 是**界面设计的主要参照** ——
用户明确要求 C 端尽量还原它。下面是从它的 `app/src/main/res` 里直接读出来的结构
（183 个 layout、90 个 menu），不是从截图或 README 推测的。

### 底部导航

`menu/main_bnv.xml` 恰好四项，和 funread 当前一致：

| 项 | 图标 | 我们的对应 |
| --- | --- | --- |
| `bookshelf` 书架 | `ic_bottom_books` | `/web` |
| `discovery` 发现 | `ic_bottom_explore` | `/web/explore` |
| `rss` 订阅 | `ic_bottom_rss_feed` | `/web/rss` |
| `my` 我的 | `ic_bottom_person` | `/web/account` |

### 阅读页菜单（`view_read_menu.xml`）

这是最该对齐的一屏。它的结构是：

```
顶栏  tv_chapter_name（当前章节名）
      tv_source_action（书源名，可点 → 换源）
侧边  seek_brightness + iv_brightness_auto（竖向亮度滑块）
底部  [tv_pre 上一章] ——— seek_read_page（全书进度滑块）——— [tv_next 下一章]
      目录 | 朗读 | 界面 | 设置   ← 四个**带文字**的按钮
```

**这一屏已经对齐**（`ReaderMenu.vue`）：顶栏有章节名 + `index+1 / total` + 可点换源
的源名，底部是 `上一章 — 全书进度滑块 — 下一章`，再加一行四个带文字的按钮
`目录 | 朗读 | 界面 | 设置`。进度滑块是其中最实用的一项 —— 在上千章里跳转，滑块比
翻目录快得多。

两处刻意不同：

- **亮度滑块放进菜单里，没做侧边竖滑块。** Web 上没有原生的纵向 range 控件，自己
  做一个纵向拖拽的收益不抵成本。
- **亮度是遮罩模拟，只能压暗。** 浏览器没有屏幕亮度 API，所以滑块的 100% 是「不
  压暗」而不是「最亮」。这个限制在界面上写明了，否则用户会以为坏了。

### 详情页（`activity_book_info.xml`）

```
bg_book + vw_bg + arc_view     ← 封面做虚化背景 + 底部弧形遮罩（标志性视觉）
iv_cover / tv_name / lb_kind / tv_author
iv_web + tv_origin + tv_change_source   ← 来源 + 换源入口
ic_book_last + tv_lasted                ← 最新章节
tv_group + tv_change_group              ← 分组 + 改分组
ll_toc + tv_toc + tv_toc_view           ← 目录入口（一行，不是内嵌列表）
tv_intro
fl_action: tv_shelf | tv_read           ← 底部固定操作栏（两个按钮）
```

差别（`BookView.vue`）：封面虚化背景（`hero__bg`）、遮罩（`hero__veil`）、底部弧形
（`hero__arc`）、来源 + 换源、最新章节、目录一行入口、底部固定操作栏（`dock`）**都
有了**。剩两处不同：

- **目录既是一行入口又内嵌在下面。** 点那一行是滚动到内嵌列表，不是进新页面。Web
  上多开一层路由会让返回键的语义变模糊，而长页面滚动是浏览器的主场。
- **详情页没有改分组入口。** 分组只在书架页改（`S9`）。详情页是「这本书是什么」，
  分组是书架的组织方式，放在书架那边更顺。

### 书架条目

`item_bookshelf_grid.xml`：`iv_cover` + **`bv_unread`（未读角标）** +
`rl_loading`（22dp，检查更新时转）+ `tv_name`（12sp）+ `vw_foreground`。

`item_bookshelf_list.xml`：`iv_cover` **66×90dp**、`tv_name` 16sp、**`fl_has_new`
（有新章节标记）**、`bv_unread`，以及三行**带图标**的信息：
`iv_author`+`tv_author`、`iv_read`+`tv_read`（读到哪）、`iv_last`+`tv_last`
（最新章节），都是 13sp。

**这两种条目也已经对齐**（`ShelfView.vue`）：网格封面 100×138 + 未读角标 +
书名 12px；列表封面 **66×90**、书名 16px、未读标签，三行**带图标**的信息
（`PersonOutline` 作者 / `BookmarkOutline` 读到哪 / `TimeOutline` 最新章节）。未读
角标是 `S10`「批量检查更新」落地后才有的 —— 它需要后端先知道「上次查到多少章」。

多出来的一项：**多选批量操作**（选中后批量移出 / 移动到分组）。原版的批量操作在
菜单里，Web 上长按不可靠，所以改成显式的「多选」按钮。

### 划词菜单（`content_select_action.xml`）

`replace | bookmark | highlight | read_aloud | dict | search_content | browser | share`
—— 八项。这是实现划词时的直接清单。

### 其他菜单里值得注意的条目

最后一列是我们的状态，核对日期同上。

| 菜单 | 条目 | 说明 | funread |
| --- | --- | --- | --- |
| `main_bookshelf` | `update_toc` | 批量检查更新 | ✅ `S10` |
| `main_bookshelf` | `group_manage` / `bookshelf_layout` | 分组管理、布局切换 | ✅ `S9` / `S1` |
| `main_bookshelf` | `book_local` | 本地书籍导入 | ❌ |
| `main_explore` | `group` | 发现页按**源分组**筛选 | ❌ 发现页第一层是选源，没有源分组 |
| `main_rss` | `history` / `favorite` | 阅读历史、收藏 | ⚠️ 有收藏（`R10`），没有阅读历史 |
| `book_search` | `precision_search` / `groups_or_source` | 精确搜索、按分组限定搜索范围 | ❌ 搜索固定打全部候选源 |
| `change_source` | `change_source_sort_respond_time` | 换源列表**按响应时间排序** | ⚠️ 按「实跑成功过的排最前」排，没有响应时间 |
| `change_source` | `change_source_word_count_filter` | 按字数筛（过滤残缺源） | ❌ |
| `book_toc` | `reverse_toc` / `search` | 倒序、目录内搜索 | ✅ `B7` / `B8` |
| `book_toc` | `load_word_count` | 目录加载字数 | ❌ |
| `book_read` | `bookmark_add` / `highlight_rule` / `replace_rule` | 书签、高亮规则、替换净化 | ❌ 三项都没有 |
| `book_read` | `re_segment` / `same_title_removed` | 重新分段、去重复标题 | ❌ |
| `book_read_record` | `reading_time_sort` | **阅读时长统计**（有专门的记录页） | ❌ |

## 其他分支

| 项目 | 状态 |
| --- | --- |
| [LegadoTeam/legado](https://github.com/LegadoTeam/legado) | 已读其 `res`：菜单与排版设置面板的字段清单来自这里（`dialog_read_book_style.xml` 的九个控件）。它对 JS 规则宿主 API 的实现是接 quickjs 时的直接参考 |
| [HapeLee/legado-with-MD3](https://github.com/HapeLee/legado-with-MD3) | Material Design 3 改版。本地 clone 是稀疏的（布局目录几乎为空），要看它的视觉需要重新完整 clone |
| [Luoyacheng/legado-E](https://github.com/Luoyacheng/legado-E) | 尚未分析 |

## 逐项功能对照

核对日期 2026-10-10。funread 一列对的是 `apps/funread-web` 与 `funread-api` 的当前
源码；竞品一列取自各自 README / 部署文档与公开说明，**没有逐个跑起来验证**，所以
标 `?` 的地方是「文档里没写明」，不是「没有」。

### 小说链路

| 功能 | funread | legado APP | hectorqin | reader-dev |
| --- | --- | --- | --- | --- |
| 聚合搜索（并发多源 + 按 `book_key` 合并） | ✅ `B1` | ✅ | ✅ | ✅ 还带书名去重 |
| 搜索中间态 + 源统计四分类 | ✅ `B2` | ❌ | ❌ | ❌ |
| 搜索历史 | ✅ `B3` | ✅ | ✅ | ? |
| 精确搜索 / 按分组限定搜索范围 | ❌ | ✅ | ? | ? |
| 书籍详情（封面虚化背景 / 简介折叠 / 分类 / 字数 / 最新章节） | ✅ `B5` | ✅ | ✅ | ✅ |
| 手动换源 | ✅ `B6`，三个入口 | ✅ | ✅ | ✅ 抽屉里显示源作者与章节末尾预览 |
| 换源后按章节名重定位 + 如实告知定位方式 | ✅ `B6` | ✅ | ✅ | ✅ 保留当前章进度 |
| 换源列表按响应时间排序 / 按字数筛 | ❌ | ✅ | ? | ? |
| 目录：虚拟滚动 / 正倒序 / 跳当前 / 目录内搜 | ✅ `B7` `B8` | ✅ | ✅ | ✅ |
| 目录加载字数 | ❌ | ✅ | ? | ? |
| 沉浸式正文 + 手势 | ✅ `B9` `B10` | ✅ | ✅ | ✅ |
| 全书进度滑块 | ✅ | ✅ | ✅ | ✅ |
| 顶栏显示章节名 + 当前源（可点换源） | ✅ | ✅ | ✅ | ✅ |
| 排版设置 | ✅ 9 项，见 `B11` | ✅ | ✅ 自定义 CSS | ✅ |
| 亮度 | ⚠️ 遮罩模拟，只能压暗 | ✅ 系统亮度 | ⚠️ 同我们 | ⚠️ 同我们 |
| 朗读 | ✅ 浏览器 `speechSynthesis` | ✅ 可接外部引擎 | ✅ | ✅ |
| 自动翻页 | ✅ rAF 匀速滚动 | ✅ | ? | ? |
| 翻页动画（仿真 / 覆盖 / 滑动） | ❌ 只做滚动式 | ✅ | ✅ | ✅ 分页 / 滚动双模式 |
| 进度自动保存与恢复 | ✅ `B12`，`char_offset` | ✅ | ✅ | ✅ |
| 书签 | ❌ | ✅ | ? | ? |
| 划词菜单（高亮 / 词典 / 搜索 / 分享 / 替换） | ❌ | ✅ 八项 | ? | ? |
| 替换净化规则 | ❌ | ✅ | ✅ | ? |
| 重新分段 / 去重复标题 | ❌ | ✅ | ? | ? |
| 阅读时长统计 | ❌ | ✅ 专门的记录页 | ❌ | ? |
| 键盘快捷键 | ✅ 5 个页面 | — 原生 APP 不需要 | ✅ | ✅ |

### 书架与离线

| 功能 | funread | legado APP | hectorqin | reader-dev |
| --- | --- | --- | --- | --- |
| 网格 / 列表双视图 | ✅ `S1` | ✅ | ✅ | ✅ |
| 加入 / 移出 / 多选批量 | ✅ `S2` | ✅ | ✅ | ✅ |
| 「读到第 N 章」+ 点击续读 | ✅ `S3` | ✅ | ✅ | ✅ |
| 排序 | ✅ `S7` | ✅ | ✅ | ? |
| 分组 | ✅ `S9`，无分组表 | ✅ | ✅ | ? |
| 批量检查更新 + 未读角标 | ✅ `S10`，202 + 轮询 | ✅ | ✅ | ? |
| 批量下载到缓存 | ✅ `S4` 服务端缓存 | ✅ 真本地 | ✅ | ✅ 双向缓存 |
| **真离线（断网可读）** | ❌ 仍需连得上服务端 | ✅ | ❌ | ❌ |
| **本地书籍导入（txt / epub）** | ❌ | ✅ | ✅ | ✅ 本地书仓 |
| **OPDS** | ❌ | ❌ | ❌ | ✅ |
| **WebDAV 同步 / 备份** | ❌ | ✅ | ✅ | ✅ |

### 订阅

| 功能 | funread | legado APP | hectorqin | reader-dev |
| --- | --- | --- | --- | --- |
| Legado RSS 源（归档解析，只列能跑的 142 个） | ✅ `R1` | ✅ | ✅ | ? |
| **自填标准 feed URL + 订阅前先验证** | ✅ `R2` | ❌ | ❌ | ❌ |
| 文章列表 + `next_url` 翻页 + 分类切换 | ✅ | ✅ | ✅ | ? |
| 正文（HTML 白名单消毒）+ 复用阅读设置 | ✅ | ✅ | ✅ | ? |
| 标已读 / 全部已读 / 收藏 | ✅ | ✅ | ✅ | ? |
| 阅读历史 | ❌ | ✅ | ? | ? |
| 真未读数 | ⚠️ 只有已读数（服务端不缓存列表） | ✅ | ? | ? |
| `singleUrl` / WebView 型源（占归档 21.7%） | ❌ 显式拒绝 | ✅ 有 WebView | ✅ 配 `remote-webview` 容器 | ✅ |

### 账号与运维

| 功能 | funread | legado APP | hectorqin | reader-dev |
| --- | --- | --- | --- | --- |
| 多用户 + 数据按 `user_id` 隔离 | ✅ `A4`，四张表 | ❌ 单机单用户 | ✅ | ✅ |
| 邀请码注册 + 名额 | ✅ `A3`，库里签发 | — | ⚠️ 单个环境变量 | ? |
| 首个账号免码成 admin + 认领无账号期数据 | ✅ | — | ⚠️ 首个即管理员，无认领 | ? |
| B/C 两套凭据（管理端口令 ≠ 读者账号） | ✅ `A5` | — | ❌ | ❌ |
| **采集源管线**（登记上游 URL → 自动采集 → 候选源池） | ✅ `/admin/sources` | ❌ 手动导入书源 | ❌ 手动填远程书源 | ❌ |
| 候选源池运维（启停 / 实跑统计 / 权重 / 最近错误 / 清失败） | ✅ `/admin/pool` | ⚠️ 有源校验，无池 | ? | ⚠️ 无池，但有书源调试器 |
| **书源调试器**（逐条规则的流式日志） | ❌ | ✅ 源编辑页内 | ? | ✅ SSE 流式 |
| CLI 生命周期（`server start/status/stop`） | ✅ PID 跟着 config 走 | — | ⚠️ Docker | ⚠️ Docker |
| HTTPS / 公网可用 | ❌ cookie `secure=False`，限局域网 | — | ✅ 文档有 | ✅ |

### 我们独有的三件事

把上面几张表里 funread 一列是 ✅ 而其余三列都不是的挑出来，就这三件：

1. **采集源管线 + 候选源池。** 竞品清一色「用户自己去粘贴远程书源 URL」，我们是
   登记上游 → 自动采集 → 实跑统计 → 按「真跑通过的排最前」选源。源质量这件事上
   我们的结构是对的，而源质量正是这个产品的命门。
2. **搜索失败的可解释性。** `sources_tried` / `sources_ok` / `js_skipped` / `failed`
   透到界面，三种空态三种文案。竞品统一是「没找到」。
3. **订阅的两条腿。** 自填标准 feed 这条路 100% 可用，完全不受 legado 归档质量
   制约（归档只有 10.6% 能跑）。三个竞品都只做 legado RSS 源。

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
   **hectorqin 给出的答案是「另起一个容器」**（`hectorqin/remote-webview`），而不是
   把浏览器塞进主进程 —— 这个边界划法值得照抄：无头浏览器的内存占用和崩溃率都不
   该拖垮阅读服务本身。

## 功能缺口，按价值排序

和上面「最该看的四件事」是两类东西：那四件缺的是**实现参考**，这五件缺的是**东西
本身**，知道怎么做，只是还没做。

1. **JS 规则求值。** 同上面第 1 条，这里重复一次是因为它也是最大的功能缺口 ——
   不解决这条，上面所有功能对照都没有意义，用户搜不到书。
2. **本地书籍导入 + OPDS + WebDAV。** 三个竞品都有，我们一个没有。这是「自托管
   阅读服务」的基本盘而不是锦上添花：用户手里已有的 txt/epub 现在完全没地方放。
3. **真离线。** 我们的「离线」是服务端缓存了正文，断网仍要连得上服务端。产品清单
   里 `N6`（Service Worker）定的是 L3 不做，理由是「离线由后端缓存承担」—— 但那个
   理由只覆盖「断外网不断内网」，覆盖不了地铁。这条取舍值得重新过一遍。
4. **书签 / 划词高亮 / 替换净化。** legado 的长尾阅读功能，我们一条都没有。
   `content_select_action.xml` 的八项是现成的清单。
5. **HTTPS + secure cookie。** 公网部署的门槛。现在 cookie 是 `secure=False` /
   `https_only=False`，所以这套服务明确只适用于局域网。

## 和 APP 本体的定位差别

这一节只对 **gedoor/legado 本体**（原生 APP）。上面那两个服务端竞品和我们是同一
形态，不受这一节的约束 —— 分清这件事很重要：**「因为我们是 Web 所以做不到」和
「只是还没做」是两回事**，混起来会给自己找现成的借口。

**和 APP 本体最大的区别就一条：它做 APP，funread 做 Web。** 而且 funread 的 Web
要同时覆盖两种形态 —— 手机浏览器访问是主场景，**PC 也必须支持**，不是「顺带能用」。

这一条决定了对比时哪些能抄、哪些不能：

### 它有的，我们受形态所限没有

| legado 本体（原生 APP） | funread（Web） | 后果 |
| --- | --- | --- |
| WebView | 无 | `singleUrl` 型源（订阅源归档的 21.7%）它能支持，我们只能显式拒绝。要补就得接无头浏览器，而且要像 hectorqin 那样另起容器 |
| 系统亮度 API | 只能盖遮罩 | 我们的亮度**只能压暗不能调亮**，滑块的 100% 是「不压暗」 |
| 本地文件系统 | 服务端存储 | 「离线」的语义不同：它是真离线，我们是「正文已抓到服务端」，仍需连得上服务端。**但「本地书籍导入」不属于这一档** —— 两个服务端竞品都做了（上传到服务端），我们只是没做，见「功能缺口」X2 |
| 一个用户一台设备 | 多用户、数据按人隔离 | 它的数据层是设备本地 Room；我们是服务端 SQLite/MySQL + `user_id` 隔离。**架构不能照搬** |
| 系统级手势与返回键 | 浏览器的历史栈 | 返回行为要自己兜（`TopBar` 的 `goBack` 会在没有 history 时回 fallback） |

### 我们有的，它没有

| funread（Web） | 后果 |
| --- | --- |
| 一个 URL 就能分享 / 刷新回到原处 | 所以 `GET /rss/article` 刻意保持 GET —— 刷新能回到同一篇 |
| 不用安装、不用分发、不受应用商店约束 | 改一次所有设备同时生效 |
| **同一套界面要同时服务手机与 PC** | 这是最大的额外约束，见下 |

### PC 也要支持，这是 APP 不需要考虑的

原生 APP 只需要为一种形态做设计；funread 的 `/web` 要在手机竖屏和桌面宽屏上
**都好用**。四处必然不同的地方，以及各自的落地：

| 差异 | 落地 |
| --- | --- |
| **翻章交互。** 手机靠左右边缘点击；2560px 宽屏上左右各 25% 的「触控带」是 640px 的死区，非常反直觉 | `useShortcuts` —— `←`/`→` 翻章、`t` 目录、`s` 设置、`h` 换源、`p` 朗读、`a` 自动翻页、`Esc` 逐层关闭。装在 5 个页面上 |
| **导航布局。** 底部 TabBar 是移动端惯例，桌面上横跨整屏的底栏不合常规 | `SideRail.vue` 侧栏，和 TabBar 共用同一份 `TABS` 定义（两处各写一份迟早漂移）。侧栏底部直接把快捷键列出来，不让人猜 |
| **内容宽度。** 列表与网格在宽屏上不能无限铺开 | `WebLayout` 的 `web-frame--rail` 限宽；书架网格在 `@media (min-width: 900px)` 下另给列数 |
| **指针 vs 触控。** hover 只在 PC 有意义，44px 最小触控区只在触屏必要 | `useViewport` 把「有没有横向空间」和「主输入是不是手指」拆成 `isWide` / `isTouch` 两个独立判断 —— 触屏笔记本需要桌面布局**但也需要** 44px |

断点取 `WIDE_BREAKPOINT = 900`：1024 会把 iPad 横屏（正好 1024px）划到窄档，而那个
尺寸明显该用多列。

> 这一节以前写「桌面端的这几处还没专门处理，记在台账里作为待办」。两头都不对：
> 台账里从来没有这一条，而桌面端其实已经做了。
