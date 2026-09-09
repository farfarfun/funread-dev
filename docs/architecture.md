# 架构设计

## 1. 项目是做什么的

`funread` 管理 [Legado 阅读 APP](https://github.com/gedoor/legado) 用的书源(booksource)和 RSS 源(rsssource)。核心流程是:

1. 从一批「源列表 URL」(第三方站点托管的 JSON,里面是一堆书源/RSS源配置)下载数据;
2. 把每条具体的源(source)按内容 md5 去重、按站点归档到本地文件;
3. 校验每条源是否还能用(请求探活);
4. (可选)用 LLM 合并同一个站点下的多个候选版本,选出最优的一份;
5. 把最终结果写回数据库,并生成 `.tar.xz` 快照上传到远程网盘/静态站点,供 Legado APP 拉取。

这套流程本身在 `funread` 里已经存在且成熟(`GenerateSourceTask`,见下文)。**这次改造要解决的问题**是:这条流水线的"落库"环节完全依赖 `funsecret` 里配置的远程 MySQL 地址,新 clone 下来的环境如果没配好这个远程库,`sync=True` 会静默跳过 —— 数据根本落不了库,也没有任何办法在本地看到采集结果。

参考姊妹项目 `funflix`(`funflix-dev/apps/funflix` + `funflix-web`)已经验证过的模式,给 funread 补上:

- 一套「本地优先」的数据库地址解析逻辑,保证不配置任何东西也能跑起来;
- 一个可扩展的采集源注册表,方便以后加新的采集源类型;
- 把 SQLite 数据库文件备份进 `funread-dat`(现有 rss/book 快照就存在这里);
- 一个采集源管理 API,提供查询、登记、启停、删除和立即采集;
- 一个参考 funflix-web 采集源页的管理界面,跑通查看与维护闭环。

**范围明确是「数据层 + 采集源管理 API/前端」**,不是 funflix 的完整媒体处理能力(鉴权、后台 worker、Alembic 迁移、生产打包这些仍没做,见 [roadmap.md](./roadmap.md))。

## 2. 仓库地图

```
funread-dev/apps/
├── funread/                                   # Python 库 + CLI 管线 + API(hatchling 打包,uv 管理依赖)
│   └── src/funread/
│       ├── base/
│       │   └── config.py                      # 数据库地址解析(新增,本次改造的地基)
│       ├── api/                                # FastAPI 采集源管理服务(新增)
│       │   ├── app.py                          # create_app() / run()
│       │   └── v1/sources.py                   # /api/v1/sources 查询与管理
│       ├── legado/manage/
│       │   ├── source/
│       │   │   └── storage.py                  # SQLAlchemy ORM 模型 + 落库逻辑,整个数据层的核心
│       │   ├── download/
│       │   │   ├── task.py                      # GenerateSourceTask,采集管线的总入口
│       │   │   ├── context.py                    # SourceBuildContext,单次运行的共享上下文
│       │   │   ├── core/
│       │   │   │   ├── store.py                  # LocalSourceStore + Download/Dump/LoadBackup 三个 Task
│       │   │   │   ├── processor.py              # SourceProcessor(loader/source_format 抽象方法)
│       │   │   │   ├── constants.py
│       │   │   │   └── db_backup.py               # backup_sqlite_database()(新增)
│       │   │   ├── sources/
│       │   │   │   ├── factory.py                 # SourceStoreFactory + 注册表(本次改造成注册表模式)
│       │   │   │   ├── book.py                    # BookSourceProcessor
│       │   │   │   └── rss.py                     # RSSSourceProcessor
│       │   │   └── reporting/
│       │   │       ├── remote.py                   # 上传到网盘(fundrive.GithubDrive,不是 git push)
│       │   │       └── builder.py                  # 生成 HTML 报告
│       │   ├── source/check/task.py                # 校验源可用性(funworker.Pipeline 并发)
│       │   ├── source/merge/task.py                 # LLM 合并候选源(funworker.Pipeline 并发)
│       │   ├── source/sync/task.py                  # 本地文件 -> 数据库 同步(funworker.Pipeline 并发)
│       │   └── publish/entrance.py                   # 生成入口页数据,写回 funread-cache(GithubDrive)
│       ├── scripts/command.py                        # 空壳 CLI(内容全被注释掉了,当前不可用,见第 8 节)
│       └── web/                                       # nicegui 页面代码,pyproject 里 `web` extra 对应它,
│                                                       # 当前没有任何地方引用/启动,是历史遗留死代码
├── funread-web/                                # 前端(Vite + Vue3 + Naive UI)
│   └── src/views/SourcesView.vue               # 采集源管理页
└── funread-dat/                                 # 数据/备份仓库,没有安装包,只有胶水脚本 + 数据文件
    └── scripts/
        ├── init.py                              # 把 FUNREAD_DATABASE_URL 写进 funsecret
        ├── seed_sources.py                      # 写入少量已校验的公开书源/RSS列表
        ├── upload.py                             # 调 GenerateSourceTask 跑一遍完整采集
        └── backup_db.py                          # 调 backup_sqlite_database()(本次新增)
    └── hubs/
        ├── book/bak/*.tar.xz                     # 书源快照(LocalSourceStore.dumps_zip 产出)
        ├── rss/bak/*.tar.xz                       # RSS 源快照
        ├── book/pkl、book/source                   # 体积巨大(GB 级),.gitignore 掉了,不进 git
        └── db/bak/*.db                            # SQLite 数据库备份(本次新增,直接拷贝文件)
```

## 3. 数据流

```
[源列表 URL,如 https://xxx/shuyuan.json]
        │  iter_source_list_data() / DownloadSourceDataTask
        ▼
[本地文件存储 LocalSourceStore]  ──dumps_zip()──▶  [hubs/{book,rss}/bak/*.tar.xz 快照]
        │  (按站点 hostname 归档 JSON,md5 去重)
        ▼
[CheckSourceStatusTask]  探活,标记 SOURCE_STATUS_{AVAILABLE,UNAVAILABLE,BLACKLISTED}
        ▼
[SourceMergeRunner]  (可选)LLM 合并同站点多个候选版本
        ▼
[SyncLocalSourceRecordsTask]  本地文件 ──▶ SQLite/MySQL(source_detail_records / source_index_records)
        │
        ├──▶ [backup_sqlite_database()]  ──▶  funread-dat/hubs/db/bak/*.db (本次新增)
        │
        ├──▶ [funread API: /api/v1/sources]  ◀──▶  [funread-web 管理页面]
        │
        └──▶ [UploadSourceBatchesTask / PublishSourceReportTask]
                 通过 fundrive.GithubDrive 把最终 JSON 批次和报告页
                 上传到 farfarfun/funread-cache 仓库(HTTP API,不是本地 git 仓库)
```

`GenerateSourceTask.run_pipeline()` 用一组布尔开关(`load/download/check/merge/dump/sync/upload/publish`)控制跑哪几段,`run_book()`/`run_rss()` 是针对两种 `source_type` 的便捷封装。现有处理阶段没有重写;源列表读取增加了“跳过已停用记录”和采集成功/失败状态回写。

## 4. 数据库设计

三张表,定义在 `funread/legado/manage/source/storage.py`,用 SQLAlchemy `DeclarativeBase` + `Base.metadata.create_all()` 建表(没有 Alembic,原因见第 7 节):

- **`source_list_records`**:一个「源列表 URL」的抓取状态。除 `url`、`source_type`、`source_count`、`last_queried_at` 外,还保存 `enabled`、连续失败次数、最近错误和最近成功时间。带自增 ID 的地址以一条含 `{id}` 的 URL 模板保存,由 `increment_start`/`increment_stop` 定义内部 `range(start, stop)`；不会把每个 ID 展开成多条采集源记录。启动时会给旧表自动补列。
- **`source_detail_records`**:一条具体的源(url_md5)分配到的稳定数字 id、状态(`SOURCE_STATUS_PENDING/AVAILABLE/UNAVAILABLE/BLACKLISTED`)、版本号。主键是 `(source_type, url_md5)`,`id` 单独唯一 —— Legado 客户端历史上依赖这个自增 id,所以做过一次 schema 迁移(`_migrate_source_detail_records_table`,启动时自动检测并迁移旧表结构,新库不会触发)。
- **`source_index_records`**:按内容 md5 索引的元数据(`hostname`、`cate1`、`url_id`),用于去重合并阶段快速判断"这个内容之前见过没有"。

`funread/api/v1/sources.py` 管理 `source_list_records`:登记时读取 JSON 并自动识别书源/RSS,支持启停、立即重新采集、重置刷新时间和删除。`source_detail_records`/`source_index_records` 仍未直接暴露;删除列表记录不会删除已经生成的具体源记录。

## 5. 数据库地址解析(`funread/base/config.py`)

```python
def resolve_database_url() -> str:
    # 1. 环境变量 FUNREAD_DATABASE_URL,最高优先级,本地/CI 覆盖用
    # 2. funsecret 里的 funread/cache/source/db_url(沿用原有 key,没有改)
    # 3. 本地 SQLite 兜底:~/.cache/farfarfun/funread/funread.db
    ...  # 三层都不抛异常,funsecret 读取失败会被 catch 掉,永远有返回值
```

这是照抄 `funflix/base/config.py` 的模式搬过来的(funflix 早就踩过同样的坑)。**关键约束:这台机器上的 `funsecret` 已经配置了一个真实的生产 MySQL 地址**(`funread/cache/source/db_url`),所以：

- 任何本地调试 / 跑测试,**必须显式设置 `FUNREAD_DATABASE_URL` 指向本地 sqlite 文件**,否则会连到生产库上执行写操作。这不是假设性风险,是这次开发过程中真实遇到的情况。
- `is_sqlite_url()` / `sqlite_path()` 是给 `db_backup.py` 判断"当前是不是本地 SQLite、文件在哪"用的两个小工具函数。

`storage.py` 里原来的 `_get_database_url()` 直接委托给 `resolve_database_url()`,不再在读不到 funsecret 时返回 `None` —— 连带把 `_get_engine()` / `_get_session_factory()` 里"读不到 URL 就抛 `ValueError`"的分支也删掉了,因为 resolver 现在保证永远有值。

引擎创建时(`_get_engine`)如果解析出来是 sqlite,会挂一个连接级 `event.listen` 做 PRAGMA 调优(同样照抄 funflix 的 `_tune_sqlite`):

- `foreign_keys=ON`:SQLite 默认不强制外键;
- `journal_mode=WAL`:CLI 管线跑的时候允许别的进程(比如 API)同时读;
- `busy_timeout=5000`:锁冲突时等一等,而不是直接抛 "database is locked"。

funread 现有代码全是**同步** SQLAlchemy(`sessionmaker`,不是 `async_sessionmaker`),这次特意没有引入 asyncio/aiosqlite —— funflix 是异步的,但那是历史选择,这里没必要为了"看起来和 funflix 一样"去动现有代码的同步模型,API 层直接用同步 session 就够了(FastAPI 的同步 `def` 路由会自动丢到线程池跑,不会阻塞事件循环)。

## 6. 采集源注册表(`sources/factory.py`)

改造前是 if/elif 硬编码两个类型;改造后:

```python
_REGISTRY: Dict[str, Tuple[Type[LocalSourceStore], str]] = {}

def register_source_type(source_type: str, processor_cls, cate1: str) -> None:
    _REGISTRY[source_type] = (processor_cls, cate1)

register_source_type("booksource", BookSourceProcessor, cate1="book")
register_source_type("rsssource", RSSSourceProcessor, cate1="rss")
```

以后接一个新的采集源站点/格式,只需要:

1. 写一个 `class XxxProcessor(SourceProcessor)`,实现 `loader()` 和 `source_format()`(参考 `sources/book.py` / `sources/rss.py`);
2. 在 `factory.py` 底部调一行 `register_source_type("xxxsource", XxxProcessor, cate1="xxx")`。

不需要改 `SourceStoreFactory.create()` 本身,也不需要改 `SourceBuildContext`/`GenerateSourceTask` —— 它们都是拿 `source_type` 字符串去查注册表。这是照抄 funflix `services/collect/registry.py` 的思路,但**没有**照抄它的"从 URL 自动探测 source_type"那部分(`detect_source()`),因为 funread 这边一直是调用方显式传 `source_type` 字符串,没有这个需求。

## 7. SQLite → funread-dat 备份

`db_backup.py::backup_sqlite_database(dest_dir)`:

- 用 `resolve_database_url()` 拿当前地址;
- 如果不是 sqlite(生产环境跑的是 MySQL),记一条日志、返回 `None`,什么都不做 —— MySQL 有自己的备份手段,不归这个函数管;
- 如果是 sqlite,用 Python 标准库 `sqlite3.Connection.backup()` 把一致性快照写到 `{dest_dir}/funread-{timestamp}.db`;不能直接 `copy2`,因为当前启用了 WAL,只复制主文件可能漏掉尚未 checkpoint 的数据。**特意没有打 `.tar.xz`**(和现有 rss/book 快照的做法不一样)——这是产品明确要求的:"最好是直接备份 sqlite.db 文件",这样可以直接拿 `sqlite3` 打开检查,不用先解压。

`funread-dat/scripts/backup_db.py` 是这个函数的胶水脚本,固定备份到 `hubs/db/bak/`,写法上和 `init.py`/`upload.py` 保持一致(顶层直接调用,不包 `if __name__ == "__main__"`,和这个仓库其他脚本风格一致)。

备份文件落到 `funread-dat` 工作区之后,**需要人工(或者以后接 CI)`git add && commit && push`** —— 和现在处理 `hubs/{book,rss}/bak` 的方式完全一致,这次没有加自动 git 提交逻辑,备份脚本只管把文件拷贝出来。

## 8. 采集源管理 API(`funread/api/`)

```
funread/api/
├── app.py          # create_app():FastAPI 实例 + /healthz;lifespan 里跑一次 init_source_db()
└── v1/sources.py   # 列表/登记/启停/删除/采集/重置刷新时间
```

对比 funflix `api/app.py` 的取舍:

- **当前没有鉴权**:和 funflix 不同,现在依靠前后端都默认监听 `127.0.0.1` 限定为本机管理工具。不能把 `8811` 直接暴露到公网;需要远程使用时必须先补登录/session。
- **没有异步**:见第 5 节,和现有 storage.py 保持同步一致。
- **没有 CORS**:浏览器只访问 `funread-web` 的同源 `/api`;前端服务再把请求转发到默认监听 `127.0.0.1:18811` 的后端,和 funflix-web 的调用方式一致。
- `lifespan` 只做了 `init_source_db()`(建表 + 连接探测),没有像 funflix 那样起后台 worker —— 这次范围里压根没有 worker。

`pyproject.toml` 新增了 `api` extra(`fastapi` + `uvicorn[standard]`)和 `[project.scripts] funread-api = "funread.api.app:run"` 入口,原有的 `web` extra(`nicegui`)是历史死代码,没有动它,也没有复用它的名字。

## 9. 前端(`funread-web/`)

从空仓库(只有一个 README)搭的最小 Vite + Vue3 + TS 单页:

```
funread-web/
├── package.json        # Vue、Naive UI、Ionicons 与 Vite 工具链
├── index.html
├── src/
│   ├── api/              # 同源 API 客户端与类型
│   ├── styles/tokens.css # 与 funflix-web 一致的主题/可访问性基础变量
│   ├── views/SourcesView.vue # 筛选、排序、批量操作、分页与登记弹窗
│   ├── App.vue           # Naive UI 主题与 Provider
│   └── main.ts
├── vite.config.ts        # 前端固定 8811;/api、/healthz 内部转发到后端 18811
└── pnpm-workspace.yaml   # allowBuilds: esbuild: true(见 development.md 的 pnpm 坑)
```

采集源页直接复用 funflix-web 的 Naive UI 交互模式:全量排序、行/批量选择、四路操作队列、筛选、分页、登记弹窗和深浅主题。没有引入 `vue-router`(只有一个页面)。开发服务与构建预览固定在 `8811`,把同源 `/api`、`/healthz` 转发到 `FUNREAD_API_BASE_URL`(默认 `http://127.0.0.1:18811`)。

## 10. `funread-cache` 是什么、不是 submodule

`funread-dev` 最开始把 `funread-cache` 也当成第四个 submodule 加了进来,后来确认这是错的:`funread-cache` 是一个**只通过 `fundrive.GithubDrive`(HTTP API)读写的远程仓库**,承载的是 `UploadSourceBatchesTask`/`PublishSourceReportTask`/`UpdateEntrance` 这几个任务上传的最终产物(JSON 批次、HTML 报告、入口页数据),代码里从来没有对它做过本地 `git clone`/`git commit` —— 全部是通过 GitHub API 上传文件。把它 checkout 到本地工作区没有意义,所以从 `.gitmodules` 里删掉了。**不要把它加回来。**

## 11. 已知技术债 / 限制

- **`funread/scripts/command.py` 是空壳**:整个文件内容被注释掉了,`pyproject.toml` 也没有指向它的 `[project.scripts]` 入口。如果以后想要一个统一 CLI(而不是让人手写 `python -c "..."` 或者去 `funread-dat/scripts/` 下翻脚本),这里需要重新实现。
- **`funread/web/` 是死代码**:nicegui 页面,`pyproject.toml` 里的 `web` extra 对应它,但没有任何入口调用/启动它。和这次新加的 `funread-web`(独立的 Vite 前端仓库)是两个不相关的东西,命名容易混淆,需要留意别搞反了。
- **测试范围仍以核心数据路径为主**:`funread/tests/` 已覆盖 `storage.py`、数据库配置、采集源 API 管理闭环和 SQLite WAL 在线备份;真实外网采集与远程发布仍依赖 mock 和手工 smoke test(见 development.md 的"验证 checklist")。
- **`funread-web` 没有生产进程管理方案**:`pnpm dev` 与 `pnpm preview` 已能同源反代 API,但还没有 funflix-web 的安装包、PID/日志和 start/stop/restart CLI。
