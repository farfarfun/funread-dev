# SQLite → funread-dat 备份


`db_backup.py::backup_sqlite_database(dest_dir)`:

- 用 `resolve_database_url()` 拿当前地址;
- 如果不是 sqlite(生产环境跑的是 MySQL),记一条日志、返回 `None`,什么都不做 —— MySQL 有自己的备份手段,不归这个函数管;
- 如果是 sqlite,用 Python 标准库 `sqlite3.Connection.backup()` 把一致性快照写到 `{dest_dir}/funread-{timestamp}.db`;不能直接 `copy2`,因为当前启用了 WAL,只复制主文件可能漏掉尚未 checkpoint 的数据。**特意没有打 `.tar.xz`**(和现有 rss/book 快照的做法不一样)——这是产品明确要求的:"最好是直接备份 sqlite.db 文件",这样可以直接拿 `sqlite3` 打开检查,不用先解压。

`funread-dat/scripts/backup_db.py` 是这个函数的胶水脚本,固定备份到 `hubs/db/bak/`,写法上和 `init.py`/`upload.py` 保持一致(顶层直接调用,不包 `if __name__ == "__main__"`,和这个仓库其他脚本风格一致)。

备份文件落到 `funread-dat` 工作区之后,**需要人工(或者以后接 CI)`git add && commit && push`** —— 和现在处理 `hubs/{book,rss}/bak` 的方式完全一致,这次没有加自动 git 提交逻辑,备份脚本只管把文件拷贝出来。
