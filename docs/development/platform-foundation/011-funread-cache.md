# `funread-cache` 是什么、不是 submodule


`funread-dev` 最开始把 `funread-cache` 也当成第四个 submodule 加了进来,后来确认这是错的:`funread-cache` 是一个**只通过 `fundrive.GithubDrive`(HTTP API)读写的远程仓库**,承载的是 `UploadSourceBatchesTask`/`PublishSourceReportTask`/`UpdateEntrance` 这几个任务上传的最终产物(JSON 批次、HTML 报告、入口页数据),代码里从来没有对它做过本地 `git clone`/`git commit` —— 全部是通过 GitHub API 上传文件。把它 checkout 到本地工作区没有意义,所以从 `.gitmodules` 里删掉了。**不要把它加回来。**
