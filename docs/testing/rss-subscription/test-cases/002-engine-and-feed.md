# 归一化、引擎与 feed 解析

## 归一化（26 个）

| 组 | 覆盖 |
| --- | --- |
| 顶层字段 | `sourceIcon` / `sortUrl` / `singleUrl` / `loadWithBaseUrl`，含字符串形态的布尔值 |
| 扁平规则 | 八个 `rule*` 字段落进 `ruleRss` 组 |
| 别名同义 | `ruleNextPage` 与 `ruleNextArticles` → 同一个键 |
| 优先级确定 | 两个都在时 `ruleNextPage` 赢，**且与 JSON 键序无关**（正反两种写法各测一次） |
| 嵌套形态 | `ruleRss: {...}` 被接受且覆盖扁平值；`list`/`nextUrl`/`date` 等别名 |
| 两套不互染 | RSS 源不长 `ruleToc`/`ruleContent` 组；书源不长 `ruleRss` 组 |
| 核心字段 | `RSS_CORE_FIELDS` 只有三个；`ruleLink` 缺失仍算完整 |
| **对比用例** | 同一份数据按 RSS 解析完整、按书源解析不完整 —— 这才说明那个缺口是什么 |
| `needs_js` | 扫 `ruleRss` 组 + `sortUrl` + `singleUrl`；`{{key}}` 不算 JS；不被书源字段拖下水 |
| `singleUrl` | 标记为 WebView 型，但 `is_complete` 仍可为 True —— 两件事要分开报给界面 |
| `sortUrl` | `名称::URL` 多行解析；没有时退化成单分类 |

## 规则引擎（31 个）

| 组 | 重点 |
| --- | --- |
| 分类 | 零网络（断言 `fetcher.requests == []`） |
| 列表 | 字段提取、丢掉无标题条目 |
| **默认只抓一页** | 断言 `len(fetcher.requests) == 1` —— 第二页没被抓 |
| 翻页 | `next_url` 回传、`follow=True` 连翻、页数上限、空列表终止 |
| **自指 nextPage** | 指回已访问 URL 时返回空串，否则调用方死循环 |
| `ruleLink` 兜底 | 规则缺失时取列表项自身的 `href` |
| 分类选择 | 认名称也认 URL；未登记的 URL 按原样抓（`sortUrl` 不一定穷举入口） |
| 正文 | `ruleContent` → `ruleDescription` 回退；两者都没有时抛「只能看列表」 |
| `loadWithBaseUrl` | 开则绝对化、关则保持相对（正反各测） |
| `singleUrl` | 抛 `WebViewNotSupportedError`；`allow_web_view=True` 放行 |
| JS 规则 | 抛 `JsNotSupportedError`，不静默返空 |
| `absolutize_html` | 相对 src/href 绝对化、绝对地址不动、正文文字不丢、解析不动时原样返回 |

## 标准 feed（27 个）

| 组 | 重点 |
| --- | --- |
| RSS 2.0 | 五个字段、CDATA 正文、enclosure 配图 |
| 正文优先级 | `content:encoded` 胜过 `description`（后者只是摘要） |
| Atom | `rel="alternate"` 胜过 `rel="self"` 与 `rel="enclosure"` |
| RDF | item 在 `RDF` 根下而不在 `channel` 里 |
| 容错 | 未转义的 `&` 不该判废整个 feed；只有 guid 时用它当链接；非 URL 的 guid 不当链接 |
| 配图兜底 | 从正文 HTML 里抠第一张 `<img src>` |
| **错误必须抛** | 空输入、HTML 页面、无 item、条目全空 —— 四种都抛且文案不同 |
| 辅助 | `feed_title` 自动填名、`looks_like_feed` 预检 |
