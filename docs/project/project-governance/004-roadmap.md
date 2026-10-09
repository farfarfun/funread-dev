# 后续开发计划

当前状态见 [`../project-status.yaml`](../project-status.yaml) 的里程碑台账(这里不重复一份,避免两处漂移)。
底座形态:数据层 + SQLite 一致性备份 + 采集源管理 API + 采集源管理页 + 规则引擎 + 阅读服务层;
端口固定为前端 `8811`、后端 `18811`,由前端同源反代 API。详见
[平台底座架构总览](../../development/platform-foundation/001-overview.md)。

这里列的是**候选**任务,不代表已经排期或者用户已经要求做 —— 捡下一个任务前,先跟用户确认优先级和范围,不要自己假设"既然 funflix 有就该做"。funflix 是参考,不是必须对齐的标准。

## 明确不做(除非用户明确要求)

这些是这次改造刻意跳过的,写在这里是为了防止未来的 agent"顺手"就把它们加上,导致范围失控:

- **后台 worker / 定时任务**:现在采集管线(`GenerateSourceTask`)是纯手动 CLI 触发,没有调度。要不要做成定时任务(参考 funflix 的 `worker/spawn`),取决于产品要不要"自动周期性采集",这是产品决策,不是技术顺手的事。
- **Alembic 迁移**:现在建表靠 `Base.metadata.create_all()` + 手写的 `_migrate_source_detail_records_table()`,在 SQLite/MySQL 上都验证过能用。schema 变化不频繁的情况下没必要引入 Alembic 这一层复杂度。
- **JS 规则求值**(`@js:` / `<js>` / `java.*` 宿主桥):书源覆盖率 ~63%→~95%、订阅源 10.6%→~38% 的那一跳需要接 quickjs 并实现一整套宿主 API,不和界面开发挤在一轮。当前一律显式报错,不静默降级 —— 静默返空会让界面上「不支持」和「今天没更新」分不出来。
- **`singleUrl` / WebView 型订阅源**(归档 1,344 个里 292 个,21.7%):不列进订阅源目录、订阅时当场拒绝,不做无头浏览器。
- **浏览器端 Service Worker 离线**:离线能力由后端 `reader_chapter_cache` 承担。

## 已完成的短期任务

- **规则引擎**(M1):`funread/legado/engine/` —— `SourceSpec`/`load_source`、`BookSourceEngine`(搜索/发现/详情/目录/正文)、`RuleEvaluator`(Default/css/xpath/json/正则三态与 `&&`/`||`/`%%`/`@put`/`@get`/`{{}}`)、`StaticFetcher`/`RequestsFetcher`、异常层级、`NullJsRuntime`。`tests/engine/test_no_heavy_imports.py` 强制 engine 层只许依赖 lxml/cssselect/jsonpath-ng + stdlib。
- **阅读服务层与阅读 API**(M2):`reader/{registry,service,storage}.py` 四张表(选源、聚合搜索、书架、进度、章节缓存)+ `funread-api` 的 `v1/{reader,shelf,auth}.py` 与 `security.py`(stdlib hmac 签名 session cookie)。
- **治理底座**(M3a):`.project-structure.json`、docs 迁入规范路径、`scripts/funbuild.toml`、根与各 app 的 `scripts/setup.sh`。
- **Entrypoint Contract**(M3b):`funread_api.cli` 补齐 `--config` 与跟随 config 的 PID 文件；`funread-web` 新增 `bin/cli.js` 与生产态反代(Node 标准库,不引 express)。
- **账户体系**(M3d):`reader_user` 表与 `hashlib.scrypt` 哈希、session 带 `user_id`、书架与进度的 `user_id` 迁移与认领、邀请码控制注册。两套凭据(B 端单口令 / C 端账号)互不越界。
- **C 端界面**(M3c):vue-router 拆 `/admin` 与 `/web` 并分包,搜索到正文全链路、书架、进度、离线下载、登录注册。
- **订阅源**(M4a–M4c):`SourceSpec` 的 RSS 归一化、`engine/rss.py` 与 `engine/feed.py` 两个引擎、两张新表、`RssService`、11 个端点、四个界面。实测归档 1,344 个里 142 个可直接用,加上用户自填 feed 这条 100% 可用的路径。
- **补测试**:`base/config.py` 覆盖 env var / funsecret / 兜底三层优先级,`api/` 使用 FastAPI `TestClient` + 临时 SQLite,`core/db_backup.py` 覆盖 SQLite WAL 和非 SQLite 场景。
- **采集源管理 API**:支持登记并自动识别类型、筛选分页、启停、立即采集、重置刷新时间和删除;旧表会自动补管理状态列。
- **前端体验**:按 funflix-web 的采集源页补齐全量排序、分页大小、选择/批量操作、四路队列、登记弹窗、深浅主题和移动端布局。
- **采集源种子**:`funread-dat/scripts/seed_sources.py` 已加入 5 个固定列表和 4 个自增 URL 模板；自增模板在内部展开,不会按 ID 重复落成多条采集源。

## 候选任务(短期,复用现成经验就能做)

- **暴露 `source_detail_records`/`source_index_records`**:目前 API 只管理 `source_list_records`(采集概览)。如果需要看具体某条源的可用性状态,需要新增接口。
- **`funread/scripts/command.py` 复活**:现在整个文件被注释掉了。如果需要一个统一 CLI 入口(而不是让人翻 `funread-dat/scripts/` 或手写 `python -c`),可以参考里面被注释掉的 `argparse` 结构重新实现,注意要接到当前的 `GenerateSourceTask`/`resolve_database_url` API,不要照抄注释里那些已经不存在的类(`ReadODSProgressDataTask` 等)。

## 候选任务(中期,需要先做产品/技术决策)

- **`FUNREAD_DATABASE_URL` 从 SQLite 切到生产 MySQL 的操作手册**:现在"本地 SQLite 兜底"这条路径验证得比较充分,但"测试阶段先存本地 SQLite,以后要不要切到 MySQL、怎么切、schema 怎么保证两边一致"没有文档化,`init_source_db()` 的自动迁移逻辑是否在 MySQL 上也经过验证需要确认。
- **公网暴露所需的鉴权加固**:C 端的用户表与 scrypt 口令哈希已交付(M3d),但那只解决"多个人各自用"。要真的暴露到公网还缺三样:HTTPS、`secure=True` 的 cookie、登录速率限制。现在的 cookie 是 `secure=False`(局域网纯 http 下必须如此),公网裸奔会被中间人直接抓走 session——而且账号化之后抓走的是具名账号,不再只是一个只读口令。口令重置与邮箱验证同属这一档,都没做。B 端 `/admin` 继续用单口令(见 `development/platform-foundation/009-source-management-api.md`),与 C 端账号分开,这个分离是故意的:管理端不该和读者账号共用凭据。
- **`funread-cache` 关系梳理**:它是通过 `GithubDrive` API 管理的静态内容仓库,和这次新增的 SQLite/API 数据层是两条平行的数据通路(一个给 Legado APP 消费静态 JSON,一个给内部看数据用)。要不要打通(比如 API 直接读 funread-cache 里的最终产物,而不是数据库里的中间状态),需要产品决策,不是技术问题。

## 长期

- **更多采集源接入**:注册表机制已经就绪(`register_source_type`),加新源类型是纯技术工作,写一个 `Processor` 子类 + 注册一行,不需要动现有架构。
- **生产部署**:两个 service 应用的 CLI 已就位(`funread-api server start|run|stop|status` 与 `funread-web` 同形),`start` 自己后台化并把 PID 写在 config 旁边。仍需决定要不要再套一层 systemd/容器托管 —— 现在的 CLI 够手动运维,但没有开机自启与崩溃重启。
