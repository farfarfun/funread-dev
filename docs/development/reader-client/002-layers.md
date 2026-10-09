# 三层分工

## `funread/legado/engine/` —— 纯求值

规则解析与求值。**分层禁令**：这个包只许依赖 lxml / cssselect / jsonpath-ng +
stdlib，**禁止 import requests / sqlalchemy / funsecret / funread.legado.manage**。

禁令由 `tests/engine/test_no_heavy_imports.py` 强制。理由不是洁癖：一条 import 链
就会把 `funsecret` 拉进来，而本机 funsecret 里存的是**生产 MySQL 地址** —— 一个
本来只做字符串求值的模块会因此连上生产库。

对外只看 `SourceSpec`：所有脏数据的格式漂移（Legado 2.x/3.x 的字段别名、类型
漂移、采集阶段留下的伤）都收在 `source.py` 这一个文件里。

## `funread/legado/reader/` —— 接上真实世界

把引擎接到归档文件、网络和数据库上。**这一层可以** import requests / sqlalchemy /
manage。

- `registry.py`：候选源池。扫描归档 → 静态判定 → 写 `reader_source_prefs`，
  之后选源只查表，不再碰上万个 JSON 文件。
- `service.py` / `rss_service.py`：门面。并发聚合搜索、四段流程、书架、进度、
  离线下载 / 订阅两条腿的分派。
- `storage.py`：七张表加口令哈希。

### 选源策略就是那个 ORDER BY

`list_source_prefs` 的排序顺序是选源策略的全部：

```sql
ORDER BY last_ok_at IS NULL ASC,  -- 实跑成功过的排前面
         fail_count ASC,
         weight DESC,
         url_id ASC
```

第一项最关键。采集侧的 `status == 2` 只说明某次 GET 过站点首页（`check/task.py`
从头到尾不碰 `searchUrl`），实测 150 个 `status==2` 的源里只有 6 个能从搜索走到
正文。所以它只当一个很弱的排序加分项（`weight` 加 1），真正的筛选靠
`record_source_result()` 积累出来的实跑结果。

## `funread-api/v1/` —— HTTP 边界

同步路由（funread 的存储层是同步 SQLAlchemy），pydantic v2 模型就近定义。

这一层只做三件事：鉴权、把 service 的返回包成响应模型、把引擎异常映射成状态码。

### 异常映射的那个区分

`deps.engine_errors()` 把引擎异常翻成 HTTP：

| 异常 | 状态码 | 界面该做什么 |
| --- | --- | --- |
| `LookupError` | 404 | 东西不存在 |
| `JsNotSupportedError` / `UnsupportedFeatureError` / `WebViewNotSupportedError` | 422 | **换源** —— 这个源永远不会工作 |
| 其他 | 502 | **重试** —— 源站这次抽风 |

422 和 502 分开是给界面用的。只给一个「请求失败」会让人在一个结构性不支持的源上
反复点重试。
