# 后续开发计划

当前状态(2026-09-08 完成):数据层(本地优先的数据库地址解析 + 可扩展采集源注册表)+ SQLite → funread-dat 备份 + 最小只读 API + 最小前端表格。范围是用户明确选定的「数据层 + 最小 API/前端」,不是 funflix 的完整能力对齐。详见 [architecture.md](./architecture.md)。

这里列的是**候选**任务,不代表已经排期或者用户已经要求做 —— 捡下一个任务前,先跟用户确认优先级和范围,不要自己假设"既然 funflix 有就该做"。funflix 是参考,不是必须对齐的标准。

## 明确不做(除非用户明确要求)

这些是这次改造刻意跳过的,写在这里是为了防止未来的 agent"顺手"就把它们加上,导致范围失控:

- **鉴权 / session**:API 目前完全无鉴权,数据也不敏感。加鉴权本身不难(参考 funflix 的 `SessionMiddleware` + `CurrentUserDep`),但一旦加了,CORS 全开的配置要跟着收紧,前端也要跟进登录态处理 —— 是一整块工作,不要因为"顺手"就加一半。
- **后台 worker / 定时任务**:现在采集管线(`GenerateSourceTask`)是纯手动 CLI 触发,没有调度。要不要做成定时任务(参考 funflix 的 `worker/spawn`),取决于产品要不要"自动周期性采集",这是产品决策,不是技术顺手的事。
- **Alembic 迁移**:现在建表靠 `Base.metadata.create_all()` + 手写的 `_migrate_source_detail_records_table()`,在 SQLite/MySQL 上都验证过能用。schema 变化不频繁的情况下没必要引入 Alembic 这一层复杂度。
- **naive-ui / vue-router 等前端框架**:一个页面、一张表,不需要路由和组件库。
- **生产打包/部署**(对应 funflix-web 的 `bin/cli.js` + 反向代理方案):现在只有 `pnpm dev`,没有考虑部署形态。

## 候选任务(短期,复用现成经验就能做)

- **补测试**:`base/config.py`(env var / funsecret / 兜底三层优先级)、`api/`(用 FastAPI `TestClient` + 临时 sqlite)、`core/db_backup.py`(sqlite 场景 + 非 sqlite 场景各测一遍)。可以照抄 `tests/test_source_download_storage.py` 用 `tmp_path` 的模式。**这是优先级最高的一项** —— 现在这几块新代码只做过手工 smoke test,没有回归保护。
- **API 分页/筛选补全**:`GET /api/v1/sources` 现在只有 `limit`/`offset`,funflix 的 `list_sources` 还支持按 `enabled`/`source_type` 筛选 —— 可以照着加 `source_type` 筛选参数,不需要照抄 funflix 的 `enabled` 字段(funread 这边没这个概念)。
- **暴露 `source_detail_records`/`source_index_records`**:目前 API 只读了 `source_list_records`(采集概览)。如果需要看具体某条源的可用性状态,需要新增接口。
- **前端体验**:分页控件(现在后端已支持 `limit`/`offset`,前端还是一把梭取全部默认 50 条)、按 `source_type` 筛选、loading/error 状态目前是最基础的文字提示,可以美化。
- **`funread/scripts/command.py` 复活**:现在整个文件被注释掉了。如果需要一个统一 CLI 入口(而不是让人翻 `funread-dat/scripts/` 或手写 `python -c`),可以参考里面被注释掉的 `argparse` 结构重新实现,注意要接到当前的 `GenerateSourceTask`/`resolve_database_url` API,不要照抄注释里那些已经不存在的类(`ReadODSProgressDataTask` 等)。

## 候选任务(中期,需要先做产品/技术决策)

- **修 `uv.sources` 相对路径问题**(见 architecture.md 第 11 节):要么把 `fundrive`/`funsecret`/`funworker` 也变成 submodule 挂到 `apps/` 下,要么改 `tool.uv.sources` 指向实际路径,要么本地开发也走 PyPI 发布版本。三种方案对其他也依赖这几个包的项目(比如 funflix)有没有影响,需要确认。
- **`FUNREAD_DATABASE_URL` 从 SQLite 切到生产 MySQL 的操作手册**:现在"本地 SQLite 兜底"这条路径验证得比较充分,但"测试阶段先存本地 SQLite,以后要不要切到 MySQL、怎么切、schema 怎么保证两边一致"没有文档化,`init_source_db()` 的自动迁移逻辑是否在 MySQL 上也经过验证需要确认。
- **鉴权 + API 写操作**(如果产品要做"手动触发一次采集"这种交互):必须先做鉴权,再加 `POST /api/v1/sources/{id}/collect` 这类接口,顺序不能反。
- **`funread-cache` 关系梳理**:它是通过 `GithubDrive` API 管理的静态内容仓库,和这次新增的 SQLite/API 数据层是两条平行的数据通路(一个给 Legado APP 消费静态 JSON,一个给内部看数据用)。要不要打通(比如 API 直接读 funread-cache 里的最终产物,而不是数据库里的中间状态),需要产品决策,不是技术问题。

## 长期

- **更多采集源接入**:注册表机制已经就绪(`register_source_type`),加新源类型是纯技术工作,写一个 `Processor` 子类 + 注册一行,不需要动现有架构。
- **生产部署**:前端打包产物往哪部署、怎么反代到 API、API 怎么跑(裸 uvicorn / gunicorn+uvicorn worker / 容器化),都还没设计,可以参考 funflix-web 的 `bin/cli.js` 方案,但不是照抄 —— funread-web 目前的复杂度远低于 funflix-web,不一定需要那一整套。
