# `SourceSpec` 的 RSS 归一化

## 缺口在哪

动手前整个订阅源链路是不通的，但原因不在数据层，而在 `engine/source.py`：
`SourceSpec` 完全是书源形态，`CORE_FIELDS` 是八个书源链路字段
（`searchUrl`、`ruleSearch.*`、`ruleToc.*`、`ruleContent.content`）。

拿它去量一个 RSS 源：`is_complete` 永远 `False` → `registry.scan()` 写进
`reader_source_prefs` 的 `enabled` 永远 `0` → **一个订阅源都进不了候选池**。

整个文件只有一处认 RSS（`source_base_url(... or normalized.get("sourceUrl"))`）。
`engine/rss.py` 根本不存在。

## 怎么补的

### 两套归一化按 `source_type` 完全分派

新增 `_RSS_FLAT_TO_GROUP`（扁平字段 → `ruleRss` 组）与 `_RSS_GROUP_ALIASES`
（`ruleRss: {...}` 嵌套形态的别名）。`_normalize_groups` 开头按 `source_type` 分岔。

**不混着来**，因为 `ruleContent` 在两边是不同的东西：RSS 源的 `ruleContent` 是
一条字符串规则，书源的 `ruleContent` 是一个组。共用一张表会让 RSS 源长出
`ruleToc`，也会让书源的正文规则被当成 RSS 正文。两个方向都有测试压着
（`test_an_rss_source_never_grows_book_groups` 与它的反面）。

### `RSS_CORE_FIELDS` 只有三个

```python
RSS_CORE_FIELDS = (("sourceUrl",), ("ruleRss", "articles"), ("ruleRss", "title"))
```

书源要八个是因为它有「搜索→详情→目录→正文」四段；RSS 只有「列表→（可选）正文」，
拿到一个能遍历的列表和每项的标题就已经能用了。

`ruleLink` 实测只有 40.3% 的源有，但缺了可以拿列表项自身的 `href` 兜底，所以
**不进核心集** —— 算进去会把可用源从 10.6% 再砍掉一截，而那部分其实是能跑的。

### `ruleNextPage` 与 `ruleNextArticles` 归一到同一个键

前者是归档里真正在用的名字（449 个 / 33.4%），后者是我们自家
`manage/publish/rss.py` 产出的源在用。两个都要认。

优先级问题：`_collect_flat_rules` 原来迭代**源数据**，于是谁在 JSON 里靠前谁赢 ——
同一个源在不同序列化下会解析出不同结果。改成迭代**映射表**，优先级就是代码里
写死的声明顺序（`ruleNextPage` 在前）。这一改顺带让书源那边的
`ruleContentUrl`/`ruleContentUrlNext` 也确定了。

### 新增的顶层字段与属性

| 字段 | 来源 | 覆盖率 | 用途 |
| --- | --- | --- | --- |
| `icon` | `sourceIcon` | 48.4% | 订阅列表的图标 |
| `sort_url` | `sortUrl` | 32.4% | 多分类入口（`名称::URL` 多行） |
| `single_url` | `singleUrl` | 21.9% | 非空 = WebView 型，跑不了 |
| `load_with_base_url` | `loadWithBaseUrl` | 94.4% | 正文相对链接要不要绝对化 |

加上 `is_rss` / `is_web_view` / `rss_categories` 三个属性。`rss_categories` 在没有
`sortUrl` 时退化成单分类（= 源地址本身），所以调用方不必分两种情况处理。

## 实测结果

对全量 1,344 个归档：

```
scanned=1344  complete=547  needs_js=427  web_view=292  enabled=142
```

142 个全部可装载（`registry.candidates(limit=200)` 返回 142）。和动手前的测算
（~145 / 10.8%）一致 —— 差的那几个是几个边缘源在归一化变严后被正确排除了。

`registry.scan()` 的 `enabled` 判定加了 `not spec.is_web_view`：那类源规则可能齐、
也可能不含 JS，但工作方式是把页面塞进 WebView，不能进候选池。`stats` 相应多一个
`web_view` 计数。书源没有这个形态，`is_web_view` 对它恒为 `False`。
