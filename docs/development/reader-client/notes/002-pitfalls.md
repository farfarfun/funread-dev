# 踩过的坑

留档的标准：**下一个人很可能重复踩，而且报错信息指错了方向**。

## `PYTHONPATH` 必须写绝对路径

`funread-api` 的 `tests/test_cli.py` 会 spawn 子进程并把 `cwd` 设成 `tmp_path`。
相对路径的 `PYTHONPATH=src:../funread/src` 到那里就失效了，报错是
`No module named 'funread_api'` —— 看着像代码坏了，其实只是路径写法。

```bash
DEV=/path/to/funread-dev
PYTHONPATH="$DEV/apps/funread-api/src:$DEV/apps/funread/src" python -m pytest tests/ -q
```

共享环境里 `~/opt/py312/site-packages` 还装了一份**非 editable** 的旧 funread，
会盖掉工作树。不带 `PYTHONPATH` 的话测试跑的是旧副本 —— 新模块 ImportError，改过
的行为测不出来，结果全是假的。

## 台账 checker 不收 `status: todo`

`project_status_checker.py` 的 `PLACEHOLDERS` 集合包含 `todo`，所以
`project-status.yaml` 里里程碑写 `status: todo` 会报「里程碑记录不完整：缺少
name、owner、due 或 status」并直接 BLOCK。字段其实填了，是**值本身**被当成占位符。

未开始的里程碑用 `planned`。

## SQLite 改不了已有表的主键

给 M2 时建的 `reader_shelf` / `reader_progress` 补 `user_id` 到**主键**里，不能用
`ALTER TABLE ADD COLUMN` 了事。`_migrate_user_scope` 走标准的重建三步：旧表改名 →
按新形状建表 → 带着 `LOCAL_USER_ID` 搬数据。搬完核对行数，不一致就抛并保留旧表 ——
宁可迁移失败也不要悄悄丢几本书。

迁移必须在 `create_all()` **之前**跑：`create_all` 只会跳过已存在的表，不会去改它
的形状。

## `_collect_flat_rules` 原来按 JSON 键序决定优先级

好几个旧字段名指向同一个规范名（`ruleNextPage`/`ruleNextArticles`、
`ruleContentUrl`/`ruleContentUrlNext`）。原实现迭代源数据，于是谁在 JSON 里靠前
谁赢 —— 同一个源在不同序列化下会解析出不同结果。改成迭代**映射表**，优先级就是
代码里写死的那个。

## 聚合搜索的 `offset` 不是真分页

每次调用都重跑一轮实时 fan-out，所以第二页不保证严格接着第一页。前端必须按
`book_key` 去重，否则「加载更多」会在列表里堆出重复条目。

## `funread-dat` 的 manifest 登记两难

`project-structure-governance` 要求 `apps/` 下每个目录都登记成 application，而每个
profile 都强制要求应用根下存在源码区（`src/`）。`funread-dat` 只有胶水脚本 + 数据
快照、标了 `package = false`，没有也不该有可导入的包。

登记 → `block` 级 `application.zone_missing`；建个空 `src/` → 造假。取舍是不登记、
接受一条 `revise`，完整留档在
[`project-governance/001-overview.md`](../../../project/project-governance/001-overview.md)
的「已知治理偏差」。
