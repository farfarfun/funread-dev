# 项目是做什么的


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

**范围明确是「数据层 + 采集源管理 API/前端」**,不是 funflix 的完整媒体处理能力(鉴权、后台 worker、Alembic 迁移、生产打包这些仍没做,见 [项目治理 / 后续计划](../../project/project-governance/004-roadmap.md))。
