# 两个引擎

## `engine/rss.py` —— `RssSourceEngine`

和 `book.py` 同一套写法（注入 `Fetcher`、不碰网络、能用 `StaticFetcher` 离线跑通），
但有三处刻意不同。

### 一次只返回一页

`articles()` 返回 `RssPage(items, next_url)`，默认只抓一页。

书源目录必须把所有页走完才能给出完整章节表；订阅列表是「加载更多」的交互，而且
源动辄几十页，一次全抓既慢又没人看。

`follow=True` 给后台任务用，会在一次调用内连翻，仍受三重终止保护：

1. URL 重复（真实源里 `nextPage` 指回当前页是常态）；
2. 空列表；
3. 页数上限 `MAX_ARTICLE_PAGES = 20`。

另外 `next_url` 在等于已访问过的 URL 时返回空串 —— 放过去调用方会死循环。

### `singleUrl` 型源显式抛异常

`_reject_web_view()` 在 `articles()` 和 `article()` 开头都调一次，抛
`WebViewNotSupportedError`。

**不能静默返空。** 否则界面上「这个源不支持」和「这个源今天没更新」长得一模一样，
而前者该换源、后者该等。`allow_web_view=True` 是给将来接上浏览器环境留的开关。

### `ruleLink` 缺失时兜底

`_link_of()` 先试 `ruleLink`（40.3% 的源有），没有就取列表项自身的 `href` ——
RSS 列表项基本都是 `<a href=...>` 结构。都拿不到就退回页面地址：至少点进去能看到
列表页本身，比一个点了没反应的空链接要好。

### `loadWithBaseUrl`

94.4% 的源开着它。`absolutize_html()` 用 lxml 的 `make_links_absolute` 把正文里的
相对链接按页面地址绝对化 —— 不做的话正文里的图片和站内链接在我们这边全是死的。

解析不动就**原样返回**：正文拿不到图片比正文整段丢掉要好得多。

## `engine/feed.py` —— 标准 feed 解析

认 RSS 2.0（`rss/channel/item`）、Atom（`feed/entry`）、RSS 1.0/RDF（`RDF/item`）。

### 不引 feedparser

要的只是「取 item 列表加五个字段」，而 lxml 已经在依赖里。feedparser 会带来一整套
它自己的容错语义和一个新依赖。约 200 行自己写完，行为完全可控。

### `recover=True` 解析

真实 feed 里未转义的 `&` 和不合法字符非常常见，严格模式会把本来能读的 feed 整个
判废。同时 `resolve_entities=False` + `no_network=True` 关掉外部实体（XXE）。

### 字段取值的优先级

| 字段 | 优先级 | 理由 |
| --- | --- | --- |
| 正文 | `content:encoded` > Atom `content` > `description` > `summary` | 前两者是全文，`description` 在多数 feed 里只是摘要 |
| 链接 | `rel="alternate"` 的 `href` > `<link>` 文本 > 像 URL 的 `guid` | Atom 里 `rel="self"` 是 feed 自己的地址、`rel="enclosure"` 是附件，都不是文章地址 |
| 配图 | `media:thumbnail` > `media:content` > `enclosure`（image/*）> 正文首图 | |
| 时间 | `pubDate` > `published` > `updated` > `date` | **原样返回不解析** |

时间不归一化成 `datetime` 是故意的：feed 里有 RFC 822、ISO 8601 和各种手写变体，
任何归一化都必然漏格式。前端只需要展示，所以存原文；真要排序时再说。

### 解析失败必须抛，不能返回空列表

```python
raise RuleSyntaxError("这是一个 HTML 页面而不是 feed 地址")
raise RuleSyntaxError("这个地址里没有 item/entry，可能不是 feed")
```

用户贴了个网页当 feed 是最常见的误用。返回空列表会让人以为「这个源没更新」，
而真正的问题是地址错了 —— 这是用户唯一能据此改正的信息。
