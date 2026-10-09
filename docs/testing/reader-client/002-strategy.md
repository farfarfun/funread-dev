# 测试策略

## 两条硬约束

### 一、不打网

`funread` 的 590 个测试一个都不访问网络。整条四段流程通过注入 `StaticFetcher`
（按 URL 查表的假 fetcher）跑通，`engine/` 的设计就是为此 —— 引擎收一个注入的
`Fetcher`，自己不碰网络。

理由不只是快：源站会死、会改版、会限速。打网的测试会在源站挂掉的那天变红，而那
跟我们的代码毫无关系，于是没人再信它。

`funread-api` 同样：`tests/test_reader_api.py` / `test_rss_api.py` 用一个两三个源
的假归档加 `StaticFetcher`。

### 二、不碰生产库

本机 funsecret 的 `funread/cache/source/db_url` 是**真实生产 MySQL**。任何忘了
覆盖 `FUNREAD_DATABASE_URL` 的测试都会写生产库。

两层防护，都是 autouse fixture：

- `apps/funread/tests/conftest.py` 把 `FUNREAD_DATABASE_URL` 与
  `FUNREAD_CACHE_ROOT` 指到 `tmp_path`；
- `apps/funread-api/tests/conftest.py` 同样做，并额外把 `security._read_secret`
  打成返回 `None`（否则「没配口令」会变成「这台笔记本上没配口令」），以及
  `delenv` 掉 `FUNREAD_API_PASSWORD` / `FUNREAD_READER_PUBLIC` /
  `FUNREAD_REGISTER_CODE`。

第二层已经验证过：**不带任何环境变量**直接 `pytest tests/`，121 个测试全过且不碰
生产库。

## 分层

| 层 | 测什么 | 怎么隔离 |
| --- | --- | --- |
| `engine/` | 规则求值、URL 选项、变量传递、翻页终止 | `StaticFetcher` + 手写 HTML/JSON 样本 |
| `reader/` | 选源排序、聚合搜索、书架/进度/缓存、账号与迁移 | tmp_path SQLite + 注入 fetcher |
| `funread_api/` | 鉴权边界、状态码映射、响应形状 | `TestClient` + 假归档 |
| `funread-web` server | 配置解析、反代、SPA fallback、目录穿越 | `node:test` + 临时 dist + 假后端 |

## 分层禁令是测出来的

`tests/engine/test_no_heavy_imports.py` 强制 `engine/` 只依赖 lxml / cssselect /
jsonpath-ng + stdlib，**禁止** requests / sqlalchemy / funsecret /
`funread.legado.manage`。

一条 import 链就会把 funsecret 拉进来，而它背后是生产 MySQL。这个测试在加了
`engine/rss.py` 与 `engine/feed.py` 之后仍然通过。

## 前端没有组件测试

funread-web 的 38 个测试全是**服务端**部分（`server/config.js`、`server/serve.js`）——
那是进程生命周期和反代逻辑，错了会让整个服务不可用。

Vue 组件没有单测框架，也不在本轮引入。界面的验证靠 `pnpm build`（含 `vue-tsc -b`
的全量类型检查）加实机走查，见
[`test-report/001-overview.md`](./test-report/001-overview.md)。

这是明确的取舍：引 vitest + testing-library 是一轮独立工作量，而当前界面的风险更多
在「真机上安全区对不对、虚拟滚动卡不卡」这类测不出来的地方。
