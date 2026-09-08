# funread-dev 项目文档

`funread-dev` 是一个多仓库(submodule)工程,把 funread 相关的几个独立 GitHub 仓库拼装到同一个工作区里,方便一起开发和联调。这里的文档是给**接手开发的 agent / 新同学**看的,目的是不用重新读一遍代码或聊天记录就能知道:这个项目现在长什么样、为什么长这样、下一步该做什么。

## 文档索引

- [architecture.md](./architecture.md) —— 整体架构设计:仓库/模块地图、数据流、数据库设计、关键设计取舍及原因、已知技术债。**开始动手前必读。**
- [development.md](./development.md) —— 本地开发环境搭建、运行方式、已踩过的坑(uv 依赖解析 bug、pnpm 审批构建脚本等)、一套可以照抄验证环境是否正常的操作步骤。
- [roadmap.md](./roadmap.md) —— 后续开发计划,按优先级列出候选任务,以及明确写死「当前不做」的范围,避免过度设计。

## 仓库结构一览

```
funread-dev/                 # 本仓库(父仓库),只放 .gitmodules 和跨仓库文档
├── docs/                    # 就是这里
└── apps/
    ├── funread/              # 后端库 + CLI 管线 + 数据层 + 只读 API(submodule)
    ├── funread-web/           # 前端(Vite + Vue3 + TS,submodule)
    └── funread-dat/            # 数据/备份仓库,只有胶水脚本 + 数据快照(submodule)
```

三个 submodule 各自是独立的 GitHub 仓库(`farfarfun/funread`、`farfarfun/funread-web`、`farfarfun/funread-dat`),有自己的 git 历史,要单独 commit/push,`funread-dev` 只负责记录三者的 commit 指针。

> `funread-cache` **不是** submodule,也不应该被加回来 —— 它是一个只通过 `fundrive.GithubDrive`(HTTP API)读写的远程仓库,承载采集产物的静态发布内容,和这个工作区里的代码没有本地检出关系。细节见 [architecture.md 的「funread-cache 是什么」一节](./architecture.md#funread-cache-是什么不是-submodule)。
