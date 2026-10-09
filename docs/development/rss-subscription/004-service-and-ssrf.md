# 服务层与 SSRF 边界

## `RssService` 的分派

对外一组方法（`available_sources` / `subscribe_*` / `articles` / `article` /
`mark_*`），内部按订阅行的 `kind` 分派到两个引擎。

### 抓取成败都记进订阅行

`articles()` 用 try/except 包住，成功清掉 `last_error`、失败写进去，两种情况都
更新 `last_fetched_at`。

界面要能解释「为什么这个订阅是空的」—— 不记的话一次抓取失败和「没有新内容」在
界面上完全一样。

### 订阅前就验证

- `subscribe_legado`：先 `_spec()` 解析，`singleUrl` 型与规则不全的当场拒掉。
  让用户订上一个点开永远是错误提示的源，比当场说清楚要糟得多。
- `subscribe_feed`：先抓一次并 `parse_feed`，失败不入库。

### `article()` 对 feed 要重抓一次

标准 feed 的正文在列表响应里就有，但服务端不缓存列表，所以读一篇文章要重抓一次
feed 再按链接找。看着浪费，但比维护一份会过期的正文缓存简单得多 —— 而订阅文章
本来就不缓存正文（时效性强、量大、收益低）。

找不到对应链接时抛 `LookupError("这篇文章已不在 feed 里")`，路由翻成 404。这是
真实会发生的：feed 通常只保留最近 N 条。

### 正文规则需要 JS 时停用源

`article()` 捕获 `JsNotSupportedError` / `UnsupportedFeatureError` 后调
`record_source_result(..., disable_after=1)`。结构性不支持，下次选它结果一样 ——
一次就停用，不要让它继续占候选池的名额。

## SSRF 边界

**`POST /rss/subscriptions` 在 `kind="feed"` 时会让服务端去拉调用方给的任意
URL。** 这是一个 SSRF primitive，和 `v1/sources.py` 的 `_download()` 同性质。

### 守卫

整组 `/rss` 端点挂 `require_user`，这保证两件事：

1. **未登录不可达**；
2. **不随 `FUNREAD_READER_PUBLIC` 放开** —— 那个开关是关于「读」的，不是关于
   「让服务端替你发请求」。

读者账号有邀请码门槛（`FUNREAD_REGISTER_CODE`，默认关闭），所以这里的「已登录」
等于「运营者放进来的人」。

两条都有测试：`test_rss_needs_an_identity_once_accounts_exist` 与
`test_reader_public_does_not_open_the_ssrf_endpoint`。

### 做了的收口

- **只认 http / https。** `file://`、`ftp://`、`javascript:` 一律 400。
- **响应 8MB 上限**（`MAX_FEED_BYTES`）。用户给的是任意 URL，没有上限就等于把
  内存交给对方。

### 没做的，以及为什么

**不屏蔽内网地址。** 自托管局域网里订阅同网段另一台机器（自己的 RSS 桥、
FreshRSS、NAS 上的服务）是**正当需求**，屏蔽会把真实用法堵死。

这个取舍成立的前提是整个服务只在局域网内使用，而那本来就是这个项目的部署前提
（见[产品范围与约束](../../product/reader-client/003-scope-and-constraints.md)）。
要暴露到公网的话，这一条和 HTTPS、速率限制一起需要重新考虑。

## `variables` 必须整条链回传

和书源那边的 `BookInfo` 同一个道理：规则可以在**列表页** `@put` 存变量、在
**正文页** `@get` 取。中途丢掉 `variables`，用这个模式的源会静默读到空正文。

链路是：`GET /rss/articles` 的每一项带 `variables` → 前端跳转时塞进路由 query →
`GET /rss/article?variables={JSON}` 回传 → 服务层传给引擎。

`/rss/article` 是 GET（要保持 URL 可链接 —— 刷新能回到同一篇），所以 `variables`
以 JSON 编码走 query 而不是走请求体。格式坏了是 **422 而不是静默当空** ——
静默丢掉变量正是这个参数存在要防的那种失败。

实测全归档只有 2 个源用这个模式，而且**都不在可用池里**（都需要 JS）。所以这条
目前不影响任何能跑的源 —— 但引擎已经产出这些值，这里丢掉就意味着接上 JS 运行时
的那天这些源会悄无声息地坏掉。

## 两张表的设计

见 [`schema/001-schema.sql`](./schema/001-schema.sql) 的注释。两个要点：

- `sub_id = md5(kind\n来源标识)` 而不是自增：重复订阅同一个源要幂等。两个人订
  同一个源得到同一个 `sub_id`，所以主键必须是 `(user_id, sub_id)`。
- `reader_rss_article_state` **只存状态不存正文**，但标题和链接存一份快照 ——
  收藏列表要能在文章滚出源站首页之后照常渲染。`set_article_state` 的 `meta` 只在
  建行时写，之后不覆盖。
