# 阅读端技术设计

阅读端跨三个应用：`funread`（规则引擎 + 阅读服务层）、`funread-api`（HTTP 层）、
`funread-web`（界面 + 生产态反代）。这一包只写阅读端这条链，平台底座（数据库地址
解析、采集管线、源注册表）在
[`docs/development/platform-foundation/001-overview.md`](../platform-foundation/001-overview.md)。

## 章节目录

| 章节 | 内容 |
| --- | --- |
| [002-layers.md](./002-layers.md) | 三层分工与那条分层禁令 |
| [003-auth.md](./003-auth.md) | 两套凭据、session 格式、隐式本地身份 |
| [004-progress-and-cache.md](./004-progress-and-cache.md) | 进度与离线缓存的实现决定 |
| [openapi/001-openapi.yaml](./openapi/001-openapi.yaml) | 接口契约（由应用导出，不手写） |
| [schema/001-schema.sql](./schema/001-schema.sql) | 五张表（由模型生成，不手改） |
| [notes/001-overview.md](./notes/001-overview.md) | 开发过程中值得留档的坑 |

## 数据流

```
浏览器
  │  同源请求 /api/v1/**
  ▼
funread-web（Node，server/serve.js）
  │  反代（判定排在 SPA fallback 之前，所以后端路径永远不会被页面路由撞上）
  ▼
funread-api（FastAPI，同步路由）
  │  v1/{auth,reader,shelf}.py → security.require_{session,reader,user}
  ▼
funread.legado.reader.ReaderService
  │  registry（候选源池）+ storage（五张表）
  ▼
funread.legado.engine.BookSourceEngine
  │  纯求值，不碰 IO
  ▼
Fetcher（RequestsFetcher / StaticFetcher）→ 源站
```

两件事值得单独指出：

- **反代不是可选项。** 没有它浏览器会直接打 `funread-api` 然后撞 CORS，而
  `funread-api` 刻意不挂 CORS 中间件 —— 给后端开放任意 origin 比同源反代差得多。
- **引擎层不碰网络。** `BookSourceEngine` 收一个注入的 `Fetcher`，所以整条四段
  流程能用 `StaticFetcher` 在离线单测里跑通。`funread` 的 532 个测试一个都不打网。
