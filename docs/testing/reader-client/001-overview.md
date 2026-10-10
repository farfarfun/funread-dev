# 阅读端测试说明

## 章节目录

| 章节 | 内容 |
| --- | --- |
| [002-strategy.md](./002-strategy.md) | 测试策略、怎么跑、以及那条「不打网」的硬约束 |
| [test-cases/001-overview.md](./test-cases/001-overview.md) | 用例清单 |
| [test-report/001-overview.md](./test-report/001-overview.md) | 本轮执行结果 |

## 当前规模

| 应用 | 测试数 | 命令 |
| --- | --- | --- |
| funread | 652 | `PYTHONPATH=<abs>/src pytest tests/ -q` |
| funread-api | 187 | `PYTHONPATH=<abs>/api/src:<abs>/funread/src pytest tests/ -q` |
| funread-web | 38 | `pnpm test`（`node --test`，服务端那部分） |

`PYTHONPATH` **必须写绝对路径**，理由见
[`development/reader-client/notes/002-pitfalls.md`](../../development/reader-client/notes/002-pitfalls.md)。
