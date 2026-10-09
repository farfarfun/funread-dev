# 规则引擎用例（305 个）

| 文件 | 组 | 重点 |
| --- | --- | --- |
| `test_source_spec.py` | 书源归一化 | 2.x 扁平字段 ↔ 3.x 嵌套结构、类型漂移、`ruleBookContent` 的误映射纠正 |
| `test_source_spec_rss.py` | 订阅源归一化 | `RSS_CORE_FIELDS` 只有三个、`ruleNextPage`/`ruleNextArticles` 同义且优先级确定、两套归一化互不污染 |
| `test_default_dialect.py` | Default 方言 | `type.name.index@output` 的歧义解析（列表规则 vs 字段规则两个入口） |
| `test_dialects.py` | css / xpath / jsonpath | 三种方言的定位与取值 |
| `test_combinators_and_regex.py` | 组合子 | `&&` / `\|\|` / `%%` 与正则三态 |
| `test_variables_and_interpolation.py` | 变量 | `@put` / `@get` / `{{}}`，以及跨阶段传递 |
| `test_url_options.py` | URL 选项 | `,{...}` 里的 method / body / headers / charset / webView |
| `test_book_flow.py` | 四段流程 | 搜索→详情→目录→正文，含翻页三重终止 |
| `test_rss_engine.py` | 订阅源两段流程 | 一次一页、`follow` 连翻、`singleUrl` 抛异常、`ruleLink` 兜底、`loadWithBaseUrl` |
| `test_feed_parser.py` | 标准 feed | RSS 2.0 / Atom / RDF、未转义 `&`、Atom 的 `rel` 挑选、解析失败必须抛 |
| `test_js_boundary.py` | JS 边界 | JS 规则一律显式抛错，不静默降级 |
| `test_no_heavy_imports.py` | 分层禁令 | `engine/` 的依赖白名单 |

## 几个值得单独说的用例

**`test_a_self_referential_next_page_is_not_handed_back`** —— 真实源里 `nextPage`
指回当前页是常态。不拦的话调用方会死循环。

**`test_an_rss_source_is_not_measured_against_the_book_core_fields`** —— 同一份
数据按 RSS 解析是完整的、按书源解析是不完整的。对比着测才说明那个缺口是什么。

**`test_errors_are_not_silently_empty_lists`**（feed 解析）—— 空输入、HTML 页面、
非 XML 三种输入都必须抛。返回空列表会让人以为「这个源没更新」。

**`test_a_single_url_source_raises_instead_of_returning_nothing`** —— 静默返空会让
「不支持」和「今天没更新」在界面上分不出来。
