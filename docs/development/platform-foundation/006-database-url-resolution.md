# 数据库地址解析(`funread/base/config.py`)


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
