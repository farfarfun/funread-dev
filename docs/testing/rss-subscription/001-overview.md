# 订阅源测试说明

策略与阅读端共用一套，见
[`docs/testing/reader-client/002-strategy.md`](../reader-client/002-strategy.md)：
不打网、不碰生产库、分层禁令由测试强制。

## 章节目录

| 章节 | 内容 |
| --- | --- |
| [test-cases/001-overview.md](./test-cases/001-overview.md) | 用例清单 |
| [test-report/001-overview.md](./test-report/001-overview.md) | 执行结果 |

## 规模

订阅源相关共 **181 个**测试：

| 层 | 文件 | 数量 |
| --- | --- | --- |
| 归一化 | `tests/engine/test_source_spec_rss.py` | 26 |
| 规则引擎 | `tests/engine/test_rss_engine.py` | 31 |
| 标准 feed | `tests/engine/test_feed_parser.py` | 27 |
| 两张表 | `tests/reader/test_rss_storage.py` | 28 |
| 服务层 | `tests/reader/test_rss_service.py` | 30 |
| API | `funread-api/tests/test_rss_api.py` | 39 |
