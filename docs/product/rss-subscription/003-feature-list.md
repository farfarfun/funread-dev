# 功能清单

| # | 功能 | 级 | 实现 |
| --- | --- | --- | --- |
| R1 | 订阅源目录：浏览可用的 Legado RSS 源 | L1 | `GET /rss/sources`，只列 `enabled` 的 142 个 |
| R2 | 自填 feed URL 订阅 | L1 | `POST /rss/subscriptions`，先抓一次验证再入库 |
| R3 | 我的订阅列表 | L1 | `GET /rss/subscriptions`，带 `read_count` 与 `last_error`。**计划里写的是「含未读数」，实际给的是已读数** —— 理由见下 |
| R4 | 取消订阅 | L1 | `DELETE`，连带清掉该订阅下的已读与收藏 |
| R5 | 文章列表，支持翻页 | L1 | `GET /rss/articles`，`next_url` 式「加载更多」 |
| R6 | 分类切换（`sortUrl` 的多分类） | L1 | `GET /rss/subscriptions/{id}/categories` |
| R7 | 文章正文阅读（复用阅读设置） | L1 | `GET /rss/article`，正文经 HTML 白名单消毒 |
| R8 | `loadWithBaseUrl` 相对链接绝对化 | L1 | lxml `make_links_absolute`，94.4% 的源开着 |
| R9 | 标记已读 / 全部已读 | L1 | 打开文章即已读；「全部已读」作用于当前页 |
| R10 | 收藏文章 | L2 | 同表加列，收藏时存标题快照 |
| R11 | 手动刷新订阅 | L1 | 重新抓列表 |
| R12 | `singleUrl` / WebView 型源 | L3 | 不列、不让订，当场说明原因 |
| R13 | 阅读历史（读过哪些文章，按时间倒排） | L3 | legado 的 `main_rss` 菜单里有。已读状态已经落库，补一个按时间倒排的视图成本不高，但要先有人真的想回头找 |
| R14 | OPML 导入 | L1 | `POST /rss/subscriptions/import`。**先入库、不逐条抓** —— 和 R2 刻意相反，理由见下 |
| R15 | OPML 导出 | L1 | `GET /rss/subscriptions/export`。只导 feed 订阅，归档源没有别的阅读器认得的地址 |
| R16 | 播客音频 / 视频附件 | L2 | 解析侧已接住（`media_url` / `media_type`），播放器归 M10 |

逐项竞品对照见
[`development/platform-foundation/013-reference-implementations.md`](../../development/platform-foundation/013-reference-implementations.md)。
R2 是其中我们独有的一项：**三个竞品都只做 legado RSS 源**，而自填标准 feed 这条路
100% 可用，不受归档质量制约（归档只有 10.6% 能跑）。

## 几条刻意的产品决定

### 订阅源目录只列能用的

需要 JS 和 WebView 的源不出现在目录里。列出来也点不开 —— 给一个必然失败的入口
比不给更糟。目录页顶部直接说明：「归档里还有大量源需要 JS 或浏览器环境，当前
版本不列出来 —— 列出来也点不开。」

### 订阅 feed 时先验证

`POST /rss/subscriptions` 会先抓一次并解析，失败就**不入库**。九成的失败是用户
贴错了（贴了网页首页而不是 feed 地址），当场给出「这是一个 HTML 页面而不是 feed
地址」，比订上之后每次刷新都空着要有用得多。

### 没有未读数，只有已读数

服务端不缓存文章列表，所以它不知道一个订阅总共有多少篇。能给的只有
`read_count`。界面上的「未读」由前端按当前这一页算 —— 这也正是「全部已读」这个
动作的实际语义（标记屏幕上这些）。

### 没有正文规则的源直接外跳

`GET /rss/articles` 的响应带 `has_content`。为 `false` 时点文章直接在浏览器新标签
打开，不进内置阅读器 —— 进去必然是空白页。界面上也提前说明一句。

### OPML 导入不验证，和单条订阅相反

R2 是「先抓一次验证，失败不入库」，R14 是「全部入库，一个都不抓」。两条看起来
矛盾，差别在数量：单条是用户手打的，九成失败是贴错，当场说比订上再报有用；
一份 OPML 动辄上百条，逐条同步抓会让导入等很久，而且其中**必然**有已经挂掉的
源 —— 那不是用户能当场改正的事。入库之后，挂掉的那些在第一次打开时由已有的
`last_error` 机制标红，列表上一眼能看出来。

### 订阅文章不缓存正文

时效性强、量大（一个活跃订阅一周几千篇），缓存收益低占用高。代价是没网读不到
订阅文章 —— 这是和小说的明确差别（小说有「下载到服务端缓存」）。
