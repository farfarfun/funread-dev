# 仓库地图


```
funread-dev/apps/
├── funread/                                   # Python 库 + CLI 管线 + API(hatchling 打包,uv 管理依赖)
│   └── src/funread/
│       ├── base/
│       │   └── config.py                      # 数据库地址解析(新增,本次改造的地基)
│       ├── legado/engine/                      # Legado 规则求值引擎(纯解析,不碰 IO/DB)
│       ├── legado/reader/                      # 阅读服务层:选源、聚合搜索、书架、进度、缓存
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
