# 自动化测试结果

## 结论

全绿。

| 应用 | 结果 | lint |
| --- | --- | --- |
| funread | **619 passed** | `ruff check src tests` —— 仅 `manage/download/reporting/builder.py` 的 49 个 star-import 报错 |
| funread-api | **131 passed** | All checks passed |
| funread-web | **38 passed**（`node --test`） | `pnpm build` 含 `vue-tsc -b` 全量类型检查通过 |

### 关于 funread 那 49 个 lint 报错

全在 `manage/download/reporting/builder.py` 一个文件里，是 `from ... import *` 带来
的 F403/F405。**在 merge-base 上就存在**（用 `git show 79a479b:` 取出那一版单独跑
ruff，同样 49 个），不是本轮引入的。

没有在本轮修：改 star-import 可能改变名字解析，而那个文件没有测试覆盖。它应该是
一次独立的、带测试的清理。

## 分模块

```
tests/engine   305 passed
tests/reader   180 passed
其余（base/net/manage/web）  134 passed
```

订阅源相关的 142 个（`test_rss_engine` + `test_feed_parser` +
`test_source_spec_rss` + `test_rss_storage` + `test_rss_service`）、
账号相关的 40 个（`test_user_accounts`），都在上述数字内。

## 隔离验证

**不带任何环境变量**直接在 `apps/funread-api` 跑 `pytest tests/`：131 个全过。
这证明 autouse fixture 真的挡住了「忘记 export `FUNREAD_DATABASE_URL`」这类事故 ——
本机 funsecret 里那个地址是生产 MySQL。

同时确认测试没有往真实 `~/.cache/farfarfun/funread/` 建库（该目录执行后仍不存在）。

## 不打网验证

`funread` 的 619 个测试在断网条件下的行为未单独验证，但全部通过注入的
`StaticFetcher` 工作，且 `test_no_heavy_imports.py` 保证 `engine/` 层连 requests
都 import 不进来。`reader/` 层的测试一律注入假 fetcher。
