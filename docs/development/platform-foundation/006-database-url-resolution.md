# 配置解析(`funread/base/config.py`)

funread 全家的**每一个**设置项都走同一条链，没有例外：

```
显式传参  >  config.toml  >  funsecret  >  兜底
```

实现只有一处 —— `funread.base.config.resolve_setting()`。各个消费点(库地址、缓存目录、管理端口令、会话密钥、监听地址……)只负责说明自己的候选位置、funsecret 坐标和兜底值，不再各自手写优先级。

**不读任何 `FUNREAD_*` 环境变量。** 环境变量在服务化部署里是最难追的一层 —— 它不在任何文件里,systemd 单元、shell profile、部署脚本都可能是来源,出问题时现场无从复原。原先靠环境变量配的东西一律写进 config.toml,见下面的键表。

## 四层分别是什么

| 层 | 入口 | 用途 |
|---|---|---|
| 1. 显式传参 | `set_overrides()` / `override()` | 命令行开关、测试夹具、一次性脚本。进程内,不落盘 |
| 2. config.toml | `use_config_file()` 注册的文件,最后兜到共享根文件 | 日常配置的正位 |
| 3. funsecret | `funread/<cate2>/<cate3>/<cate4>` | 凭据的推荐位置:不必落到每台机器的磁盘上 |
| 4. 兜底 | 本地 SQLite / 用户缓存目录 | 让一份新 clone 在没有密钥库、没有配置文件时也能跑起来 |

第 3 层的"**没配**"和"**坏掉**"必须分开(`_SECRET_ABSENT = (ImportError, KeyError, ValueError)`):前者才兜底,后者原样抛。一个坏掉的密钥库如果被默默兜底,运维会以为自己在写配置里那个库,其实在写本地 SQLite。

## 配置文件在哪

- **共享根文件 `~/.farfarfun/funread/config.toml`** —— 三个入口(核心库管线、funread-api、funread-web)都读它,所以库地址、缓存目录这类跨进程的设置只需要写一处。路径由 `shared_config_path()` 现算,**故意不走 `XDG_CONFIG_HOME`**:同一个目录树下还放 PID、日志、会话密钥,那些都不是"配置"。
- **服务自己那份** `~/.farfarfun/funread/api/config.toml` / `~/.farfarfun/funread/web/config.toml` —— 由 CLI 的 `--config` 决定,启动时 `use_config_file()` 注册进来,**优先于共享根文件**。它还承担另一件事:PID 和日志挨着 config 放(`Settings.state_dir = config_path.parent`),所以这两份文件不能并进根文件里。

查找顺序就是 `config_files()` 的返回顺序:注册的文件(先注册先优先),最后共享根文件。支持 `.toml` / `.json` / `.env` 三种扩展名(`.env` 只能写扁平键,没有段的概念)。

文件不存在不是错误(新机器上本来就没有);**解析失败是错误** —— 一个写坏了的 config.toml 如果被当成空文件,整台机器会静默跑回兜底配置。

## 键表(含原环境变量的对应关系)

共享根文件:

```toml
[database]
url = "postgresql+psycopg2://user:password@host/dbname"   # 原 FUNREAD_DATABASE_URL

[cache]
root = "~/.cache/farfarfun/funread/hub"                   # 原 FUNREAD_CACHE_ROOT

[auth]
password = "..."          # 管理端口令,原 FUNREAD_API_PASSWORD;不填＝管理端无鉴权全开
session_secret = "..."    # 原 FUNREAD_SESSION_SECRET;不填会在 api 配置目录下自动生成
reader_public = false     # 原 FUNREAD_READER_PUBLIC
register_open = true      # 原 FUNREAD_REGISTER_OPEN;闸门是邀请码,不是这个开关

[api]
host = "127.0.0.1"        # 原 FUNREAD_API_HOST
port = 18811              # 原 FUNREAD_API_PORT

[web]
host = "0.0.0.0"          # 原 FUNREAD_WEB_HOST;前端默认对外监听,后端默认只听回环
port = 8811               # 原 FUNREAD_WEB_PORT
backend = "http://127.0.0.1:18811"   # 原 FUNREAD_API_BASE_URL
```

服务自己那份用 `[server] host/port`(api 的盖掉根文件 `[api]`,web 的盖掉 `[web]`),其余段在服务文件里也可写、同样优先于根文件。

funsecret 第二层的坐标:

| 设置 | funsecret 路径 |
|---|---|
| `database.url` | `funread/cache/source/db_url` |
| `auth.password` | `funread/api/auth/password` |
| `auth.session_secret` | `funread/api/auth/session_secret` |
| `auth.reader_public` | `funread/api/auth/reader_public` |
| `auth.register_open` | `funread/api/auth/register_open` |

`host`/`port`/`backend` **不进 funsecret** —— 监听地址放密钥库没有意义,它们的链是 `命令行 > config.toml > 默认`。

### `cache.root` 也不进 funsecret(2026-10-15 起)

判据是**这个值换台机器还成不成立**:库地址、口令换台机器照样对,归档目录不是。funsecret 是跨机器共享的,存一条机器本地路径进去,等于让另一台机器去读别人的路径。

这条原本挂在 `funread/cache/path/root` 上,真出过事:密钥库里存着 `funread-dat` 还是独立仓库时的旧路径,而它后来成了 `funread-dev` 的子模块,那个目录早就不存在了。结果是

- Linux 那台解析到不存在的目录,静默兜底成空候选池 —— 表现是「搜不到书」,没有任何报错;
- macOS 那台更直接,`/home` 在 macOS 上是 autofs 挂载点,建目录当场 `OSError: [Errno 45]`,搜索接口 500。

现在它的链是 `显式传参 > config.toml [cache] root > 兜底`。密钥库里要是还留着旧值,**兜底时会打一条 warning 说清它已不再被读取、当前回落到哪里**,只打一次;检测挂在兜底那条路上,所以配了 `[cache] root` 的机器一次密钥库都不会查。`test_cache_root_ignores_the_secret_store` 钉住这一点。

类型由 `coerce=` 折平:config.toml 给的是真正的 TOML 类型,funsecret 给的永远是字符串,布尔项统一过 `as_bool()`。

## 还设着废弃环境变量怎么办

两个 CLI 启动时会检测 `DEPRECATED_ENV_VARS` 里的名字是否仍被设着(非空),命中就往 stderr 打一行:

```
warning: 环境变量 FUNREAD_DATABASE_URL 已不再被读取，请改写 config.toml 的 [database] url
```

这个检测不是装饰:既不留兼容读取、又不说一声的话,升级会静默改变行为 —— 原先靠 `FUNREAD_DATABASE_URL` 指到某个库的机器,升级后会一路掉到 funsecret 去。

## 本地调试与测试的安全线

**这台机器上的 `funsecret` 配着一个真实的生产 PostgreSQL 地址**(`funread/cache/source/db_url`,scheme 是 `postgresql+psycopg2`)。第 3 层随时可能解析到它,所以:

- 任何本地调试 / 跑测试,**必须显式把库地址压到本地 sqlite**。正位是 `config.set_overrides(database_url=...)`(进程内,不受环境影响),两个 autouse fixture 已经这么做了。这不是假设性风险,是开发过程中真实遇到过的情况。
- 起子进程的测试(`funread-api/tests/test_cli.py`)另外给子进程一个**假 HOME 加一份共享根配置** —— 子进程不继承 override,而它启动时会真的建表。假 HOME 同时让 funsecret 自己也找不到库,是第二道闸。
- `funread/tests/test_config.py::test_environment_variables_are_ignored` 钉住"环境变量层已删":万一谁把 `os.environ.get` 加回来,这条立刻红 —— 因为一旦加回来,靠 override 做隔离的夹具就会变成空操作,然后一路掉到生产库上。

## SQLite 相关

- `is_sqlite_url()` / `sqlite_path()` 是给 `db_backup.py` 判断"当前是不是本地 SQLite、文件在哪"用的两个小工具。
- `storage.py` 的 `_get_database_url()` 直接委托 `resolve_database_url()`,不会返回 `None`,所以 `_get_engine()` / `_get_session_factory()` 里"读不到 URL 就抛 `ValueError`"的分支早已删掉 —— resolver 保证永远有值。
- 引擎创建时(`_get_engine`)如果解析出来是 sqlite,会挂一个连接级 `event.listen` 做 PRAGMA 调优(照抄 funflix 的 `_tune_sqlite`):
  - `foreign_keys=ON`:SQLite 默认不强制外键;
  - `journal_mode=WAL`:CLI 管线跑的时候允许别的进程(比如 API)同时读;
  - `busy_timeout=5000`:锁冲突时等一等,而不是直接抛 "database is locked"。

funread 现有代码全是**同步** SQLAlchemy(`sessionmaker`,不是 `async_sessionmaker`),特意没有引入 asyncio/aiosqlite —— funflix 是异步的,但那是历史选择,这里没必要为了"看起来和 funflix 一样"去动现有代码的同步模型,API 层直接用同步 session 就够了(FastAPI 的同步 `def` 路由会自动丢到线程池跑,不会阻塞事件循环)。账号那套是唯一的例外(`accounts.py` 用 `async_sessionmaker`),它的引擎要额外 dispose,见该文件注释。
