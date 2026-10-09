# 订阅源执行结果

执行日期：2026-10-09。

## 结论

订阅源相关 **174 个测试全过**，含在 funread 的 590 与 funread-api 的 121 里。

```
tests/engine/test_source_spec_rss.py   26 passed
tests/engine/test_rss_engine.py        31 passed
tests/engine/test_feed_parser.py       27 passed
tests/reader/test_rss_storage.py       28 passed
tests/reader/test_rss_service.py       30 passed
funread-api/tests/test_rss_api.py      32 passed
```

全部离线（注入 `StaticFetcher`），无网络依赖。

## 对真实归档的实测

这不是单测，是拿全量 1,344 个归档跑一遍归一化与扫描 —— 用来验证那些百分比不是
算出来的而是数出来的。

```
scanned=1344  complete=547  needs_js=427  web_view=292  enabled=142
```

| 档 | 数量 | 占比 |
| --- | --- | --- |
| 规则不全 | 529 | 39.4% |
| 规则完整但需要 JS | 427 | 31.8% |
| `singleUrl`（WebView 型） | 292 | 21.7% |
| **纯 Python 可跑** | **142** | **10.6%** |

`registry.candidates(limit=200)` 返回 142 个，即候选池里每一个都真能装载（没有
「表里标着 enabled 但文件已经不见了」的残留）。

和动手前的测算（~145 / 10.8%）一致，差的几个是边缘源在归一化变严后被正确排除。

## 端到端（已执行）

见
[`testing/reader-client/test-report/003-manual.md`](../../reader-client/test-report/003-manual.md)
的全栈走查，订阅源部分：

- 订阅源目录 `total=142`，首项带 12 个分类与图标 ✓
- 贴错 feed 地址 → 400 +「无法解析为 XML，可能不是 feed 地址」✓
- 订阅归档源 → 201，分类 12 个 ✓
- 订阅**真实 feed**（Hacker News）→ 201，`preview=30` ✓
- 文章列表 4 篇 → 标已读 → 收藏 → 读正文 → 退订，全通 ✓

### 两个真实世界的观察

**归档源「SF漫画」返回 0 篇文章。** 源站的事，不是代码问题 —— 和已知风险
「书源语料大面积失效」同源。值得记的是它返回了格式正确的空页加
`has_content=false`，界面按设计显示空态与外跳提示，没有崩。这正是
「`has_content` 这个字段为什么存在」的实证。

**`ruanyifeng.com/blog/atom.xml` 返回 403。** 那个站拒绝我们的 UA。错误原样透出
（`HTTP 403 | url=... | status=403`），用户能看懂。这类站要么配 UA 要么换源，不是
解析问题。

## 未覆盖

- **真机走查**：订阅列表与文章正文在手机上的表现（安全区、横滚分类条、
  消毒后的正文排版）未实机验证。
- **大量订阅下的性能**：`/auth/accounts` 那种全量统计在几十个订阅时是逐个查的，
  没有压过。当前规模（个人自托管）下不是问题。
