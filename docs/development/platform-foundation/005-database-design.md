# 数据库设计


三张表,定义在 `funread/legado/manage/source/storage.py`,用 SQLAlchemy `DeclarativeBase` + `Base.metadata.create_all()` 建表(没有 Alembic,原因见第 7 节):

- **`source_list_records`**:一个「源列表 URL」的抓取状态。除 `url`、`source_type`、`source_count`、`last_queried_at` 外,还保存 `enabled`、连续失败次数、最近错误和最近成功时间。带自增 ID 的地址以一条含 `{id}` 的 URL 模板保存,由 `increment_start`/`increment_stop` 定义内部 `range(start, stop)`；不会把每个 ID 展开成多条采集源记录。启动时会给旧表自动补列。
- **`source_detail_records`**:一条具体的源(url_md5)分配到的稳定数字 id、状态(`SOURCE_STATUS_PENDING/AVAILABLE/UNAVAILABLE/BLACKLISTED`)、版本号。主键是 `(source_type, url_md5)`,`id` 单独唯一 —— Legado 客户端历史上依赖这个自增 id,所以做过一次 schema 迁移(`_migrate_source_detail_records_table`,启动时自动检测并迁移旧表结构,新库不会触发)。
- **`source_index_records`**:按内容 md5 索引的元数据(`hostname`、`cate1`、`url_id`),用于去重合并阶段快速判断"这个内容之前见过没有"。

`funread-api` 的 `v1/sources.py` 管理 `source_list_records`:登记时读取 JSON 并自动识别书源/RSS,支持启停、立即重新采集、重置刷新时间和删除。`source_detail_records`/`source_index_records` 仍未直接暴露;删除列表记录不会删除已经生成的具体源记录。
