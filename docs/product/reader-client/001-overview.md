# 阅读端（C 端）产品说明

阅读端是 funread 面向读者的那一半，挂在 `/web`，手机优先。采集源运维那一半在
`/admin`，是另一类用户、另一套凭据，不在本包范围内。

## 章节目录

| 章节 | 内容 |
| --- | --- |
| [002-feature-list.md](./002-feature-list.md) | 完整功能清单，按模块分组，标注交付级别 |
| [003-scope-and-constraints.md](./003-scope-and-constraints.md) | 范围边界，以及限制它的那些实测数据 |

## 一句话概括

读者在 `/web` 里搜一本书、挑一个来源、读正文、把进度和书架留在服务端；另外订阅
一批 RSS 源或自己贴的 feed 地址，在同一套阅读设置下看文章。

## 目标用户与场景

自托管这套服务的人和他家里人。典型场景是：电脑上跑着服务，手机连同一个局域网，
打开浏览器就能读。**不面向公网** —— session cookie 是 `secure=False`，这决定了
整个产品的安全假设（见 003 章）。

因此几条产品取向是被环境定死的，不是偏好问题：

- **手机优先。** 真实使用是躺着拿手机看，桌面只是顺带能用。
- **离线要能读。** 家里 WiFi 不一定稳，地铁上没有网。所以有「下载到服务端缓存」
  这个功能，而不是指望实时抓取。
- **源会坏。** Legado 的源语料大面积失效（实测 150 个标着可用的书源里只有 6 个
  真能从搜索走到正文），所以换源、失败重试、以及**把失败说清楚**是核心体验而
  不是边角。

## 相关文档

- 界面与交互：[`docs/design/reader-client/001-overview.md`](../../design/reader-client/001-overview.md)
- 接口与数据：[`docs/development/reader-client/001-overview.md`](../../development/reader-client/001-overview.md)
- 测试：[`docs/testing/reader-client/001-overview.md`](../../testing/reader-client/001-overview.md)
- 订阅源那一块的产品说明：[`docs/product/rss-subscription/001-overview.md`](../rss-subscription/001-overview.md)
