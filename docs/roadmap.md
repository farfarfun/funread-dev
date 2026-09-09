# 后续开发计划

当前状态(2026-09-09 完成):数据层 + SQLite 一致性备份 + 采集源管理 API + 参考 funflix-web 的采集源管理页;端口固定为前端 `8811`、后端 `18811`,由前端同源反代 API。详见 [architecture.md](./architecture.md)。

这里列的是**候选**任务,不代表已经排期或者用户已经要求做 —— 捡下一个任务前,先跟用户确认优先级和范围,不要自己假设"既然 funflix 有就该做"。funflix 是参考,不是必须对齐的标准。

## 明确不做(除非用户明确要求)

这些是这次改造刻意跳过的,写在这里是为了防止未来的 agent"顺手"就把它们加上,导致范围失控:

- **鉴权 / session**:当前定位是只监听 `127.0.0.1` 的本机管理工具。鉴权要连同前端登录态一起设计,在此之前不允许把管理页直接暴露到公网。
- **后台 worker / 定时任务**:现在采集管线(`GenerateSourceTask`)是纯手动 CLI 触发,没有调度。要不要做成定时任务(参考 funflix 的 `worker/spawn`),取决于产品要不要"自动周期性采集",这是产品决策,不是技术顺手的事。
- **Alembic 迁移**:现在建表靠 `Base.metadata.create_all()` + 手写的 `_migrate_source_detail_records_table()`,在 SQLite/MySQL 上都验证过能用。schema 变化不频繁的情况下没必要引入 Alembic 这一层复杂度。
- **vue-router**:仍只有一个采集源页面,不需要路由。
- **生产进程管理**(对应 funflix-web 的 `bin/cli.js`):当前 Vite 开发服务/构建预览已有反向代理,但没有安装包、PID/日志和 start/stop/restart CLI。

## 已完成的短期任务

- **补测试**:`base/config.py` 覆盖 env var / funsecret / 兜底三层优先级,`api/` 使用 FastAPI `TestClient` + 临时 SQLite,`core/db_backup.py` 覆盖 SQLite WAL 和非 SQLite 场景。
- **采集源管理 API**:支持登记并自动识别类型、筛选分页、启停、立即采集、重置刷新时间和删除;旧表会自动补管理状态列。
- **前端体验**:按 funflix-web 的采集源页补齐全量排序、分页大小、选择/批量操作、四路队列、登记弹窗、深浅主题和移动端布局。
- **采集源种子**:`funread-dat/scripts/seed_sources.py` 已加入 5 个固定列表和 4 个自增 URL 模板；自增模板在内部展开,不会按 ID 重复落成多条采集源。

## 候选任务(短期,复用现成经验就能做)

- **暴露 `source_detail_records`/`source_index_records`**:目前 API 只管理 `source_list_records`(采集概览)。如果需要看具体某条源的可用性状态,需要新增接口。
- **`funread/scripts/command.py` 复活**:现在整个文件被注释掉了。如果需要一个统一 CLI 入口(而不是让人翻 `funread-dat/scripts/` 或手写 `python -c`),可以参考里面被注释掉的 `argparse` 结构重新实现,注意要接到当前的 `GenerateSourceTask`/`resolve_database_url` API,不要照抄注释里那些已经不存在的类(`ReadODSProgressDataTask` 等)。

## 候选任务(中期,需要先做产品/技术决策)

- **`FUNREAD_DATABASE_URL` 从 SQLite 切到生产 MySQL 的操作手册**:现在"本地 SQLite 兜底"这条路径验证得比较充分,但"测试阶段先存本地 SQLite,以后要不要切到 MySQL、怎么切、schema 怎么保证两边一致"没有文档化,`init_source_db()` 的自动迁移逻辑是否在 MySQL 上也经过验证需要确认。
- **远程访问鉴权**:管理 API 已有写操作,当前只允许按默认配置监听本机回环地址。需要把 `8811` 暴露给远程用户前,必须补登录/session,不能直接公网裸奔。
- **`funread-cache` 关系梳理**:它是通过 `GithubDrive` API 管理的静态内容仓库,和这次新增的 SQLite/API 数据层是两条平行的数据通路(一个给 Legado APP 消费静态 JSON,一个给内部看数据用)。要不要打通(比如 API 直接读 funread-cache 里的最终产物,而不是数据库里的中间状态),需要产品决策,不是技术问题。

## 长期

- **更多采集源接入**:注册表机制已经就绪(`register_source_type`),加新源类型是纯技术工作,写一个 `Processor` 子类 + 注册一行,不需要动现有架构。
- **生产部署**:API 已约定监听 `127.0.0.1:18811`,前端已约定监听 `8811` 并内部反代;仍需决定正式进程由 systemd/容器托管,还是补 funflix-web 风格的 `bin/cli.js`。
