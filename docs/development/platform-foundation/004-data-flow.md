# 数据流


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
