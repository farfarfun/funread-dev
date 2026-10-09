# 订阅源技术设计

## 章节目录

| 章节 | 内容 |
| --- | --- |
| [002-source-spec-rss.md](./002-source-spec-rss.md) | `SourceSpec` 的 RSS 归一化：缺口在哪、怎么补的 |
| [003-engines.md](./003-engines.md) | `engine/rss.py` 与 `engine/feed.py` |
| [004-service-and-ssrf.md](./004-service-and-ssrf.md) | 服务层分派与那个 SSRF 边界 |
| [openapi/001-openapi.yaml](./openapi/001-openapi.yaml) | 接口契约（由应用导出，不手写） |
| [schema/001-schema.sql](./schema/001-schema.sql) | 两张表（由模型生成，不手改） |

## 数据流

```
浏览器 → funread-web 反代 → funread-api v1/rss.py
                                  │  require_user（整组）
                                  ▼
                        funread.legado.reader.RssService
                                  │  按订阅的 kind 分派
                    ┌─────────────┴─────────────┐
                    ▼                           ▼
        engine/rss.RssSourceEngine      engine/feed.parse_feed
        （规则求值，142 个归档源）      （XML 解析，用户自填，100% 可用）
                    │                           │
                    └────────── RssArticle ─────┘
                                  │
                        reader_rss_{subscription,article_state}
```

分派只影响「怎么拿到一页 `RssArticle`」。订阅表、已读状态、错误记账全是共用的。
