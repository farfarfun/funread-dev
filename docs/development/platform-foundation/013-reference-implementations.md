# 参考实现与竞品

这一章只记**是什么、可以从它那里看什么**，不做结论 —— 真正的对比分析要读过代码
之后再写，到时候各开一节。

## 上游与规则来源

| 项目 | 角色 |
| --- | --- |
| [gedoor/legado](https://github.com/gedoor/legado) | Legado 阅读 APP 本体（Android / Kotlin）。书源与订阅源的**规则语言定义方** —— `funread/legado/engine/` 的一切语义以它为准 |
| [规则说明](https://alanskycn.gitee.io/teachme/) | 社区维护的规则文档。写引擎时的第一手参考 |
| [hectorqin/reader](https://github.com/hectorqin/reader) | Legado 的第三方服务端（Kotlin）。和 funread 定位最接近的一个：都是「把 Legado 的规则搬到服务端 + 提供 Web 阅读界面」 |

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

和 funread 当前实现的差别：我们是一行五个纯图标按钮，**没有全书进度滑块**，
顶部不显示章节名与当前源。进度滑块是其中最实用的一项 —— 在上千章里跳转，滑块比
翻目录快得多。

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

差别：我们没有封面虚化背景与弧形，目录是内嵌的而不是一行入口，操作按钮不固定在
底部，也没有分组。

### 书架条目

`item_bookshelf_grid.xml`：`iv_cover` + **`bv_unread`（未读角标）** +
`rl_loading`（22dp，检查更新时转）+ `tv_name`（12sp）+ `vw_foreground`。

`item_bookshelf_list.xml`：`iv_cover` **66×90dp**、`tv_name` 16sp、**`fl_has_new`
（有新章节标记）**、`bv_unread`，以及三行**带图标**的信息：
`iv_author`+`tv_author`、`iv_read`+`tv_read`（读到哪）、`iv_last`+`tv_last`
（最新章节），都是 13sp。

差别：我们的列表封面是 48×66（偏小）、信息行没有图标、**没有未读角标与新章节
标记**（那两个需要后端支持「检查更新」）。

### 划词菜单（`content_select_action.xml`）

`replace | bookmark | highlight | read_aloud | dict | search_content | browser | share`
—— 八项。这是实现划词时的直接清单。

### 其他菜单里值得注意的条目

| 菜单 | 条目 | 说明 |
| --- | --- | --- |
| `main_bookshelf` | `update_toc` | **批量检查更新** |
| `main_bookshelf` | `group_manage` / `bookshelf_layout` | 分组管理、布局切换 |
| `main_bookshelf` | `book_local` | 本地书籍导入 |
| `main_explore` | `group` | 发现页按**源分组**筛选 |
| `main_rss` | `history` / `favorite` | 阅读历史、收藏 |
| `book_search` | `precision_search` / `groups_or_source` | 精确搜索、按分组限定搜索范围 |
| `change_source` | `change_source_sort_respond_time` | 换源列表**按响应时间排序** |
| `change_source` | `change_source_word_count_filter` | 按字数筛（过滤残缺源） |
| `book_toc` | `reverse_toc` / `load_word_count` / `search` | 倒序、加载字数、目录内搜索 |
| `book_read` | `bookmark_add` / `highlight_rule` / `replace_rule` | 书签、高亮规则、替换净化 |
| `book_read` | `re_segment` / `same_title_removed` | 重新分段、去重复标题 |
| `book_read_record` | `reading_time_sort` | **阅读时长统计**（有专门的记录页） |

## 其他分支

| 项目 | 状态 |
| --- | --- |
| [LegadoTeam/legado](https://github.com/LegadoTeam/legado) | 已读其 `res`：菜单与排版设置面板的字段清单来自这里（`dialog_read_book_style.xml` 的九个控件）。它对 JS 规则宿主 API 的实现是接 quickjs 时的直接参考 |
| [HapeLee/legado-with-MD3](https://github.com/HapeLee/legado-with-MD3) | Material Design 3 改版。本地 clone 是稀疏的（布局目录几乎为空），要看它的视觉需要重新完整 clone |
| [Luoyacheng/legado-E](https://github.com/Luoyacheng/legado-E) | 尚未分析 |

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
