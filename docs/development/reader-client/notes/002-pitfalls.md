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

## 裸元素选择器打不过 naive-ui 的运行时注入样式

`web.css` 里这条防 iOS 自动放大的规则写得没毛病，但它是**死的**：

```css
@media (max-width: 768px) {
  input { font-size: max(16px, 1em); }   /* 实测仍是 14px */
}
```

naive-ui 的样式不是构建期打包进 CSS 的，是组件挂载时注入 `<head>`；它把字号写在
`.n-input__input-el` 上（0,1,0 的类选择器），而裸 `input` 只有 0,0,1。特异度输
一截、顺序还排在后面，两头都不占。必须把 naive 自己的类名点进来，并且上
`!important` —— 注入顺序不由我们控制，只提特异度仍可能被同特异度的后来者盖掉。

```css
.n-input .n-input__input-el { font-size: max(16px, 1em) !important; }
```

同一类问题的另一面：`tokens.css` 里那条
`@media (pointer: coarse) { .n-button { min-height: 44px } }` **只管 n-button**。
自写的胶囊（书架分组）、原生 `<button>`（顶栏返回键）、行内 `<a>`（登录页的
「用邀请码注册」）都不在它覆盖范围内，各自量到 31 / 36 / 17px。

**这类 bug 读代码读不出来，只有量渲染结果才能发现**，所以手机尺寸走查用的是脚本化
的 `getComputedStyle` / `getBoundingClientRect`，不是肉眼看截图。

## feed 的 `description` 是 HTML，`pub_date` 是自由格式

两件事都踩过：

- Hacker News 的 `description` 是 `<a href="...">Comments</a>`。用 `{{ }}` 插出来
  用户看到的是一行尖括号。取纯文字用 `<template>.content`（游离片段不触发资源加载、
  不执行脚本，顺带解 HTML 实体），别手写正则 —— 两件事它都做不到。
- `pub_date` 来自源站：RSS 给 RFC-822、Atom 给 ISO-8601，还有一堆自造格式。
  **不能直接丢给 `Intl.RelativeTimeFormat`** —— 解析失败时 `new Date()` 给 NaN，
  `format(NaN, ...)` 抛 `RangeError`，整张列表跟着白掉。`formatFeedDate` 解析不出来
  就原样回显。

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
