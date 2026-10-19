# 已知技术债 / 限制

核对日期 **2026-10-18**。这一轮把搁了两天的「40 个 needs_js 源重测」做完了，
顺带揪出一个比源站存活率更根本的问题 —— 见下。

## JS 规则求值：真正的 bug 是 quickjs 从来没接进生产路径

**10-17 记的「需要重测」是对的，但原因比预想的严重。** 新写了
`net/survey.py`（抽样确定、结果落盘，见模块文档），对同一批 40 个
url_id（按 url_id 升序取前 40 个「规则完整 + 搜索链路带 JS」的书源，归档没变
就是同一批）跑了两次：

**第一次**：22 个全是 `JsNotSupportedError: 该规则需要 JS 求值，当前阶段不支持`
—— 和「接上 quickjs」的说法矛盾。查下去发现 `BookSourceEngine` /
`RssSourceEngine` 在构造时 `js` 没传就落到 `NullJsRuntime()`，而
**src 里没有任何调用方传过 `js=`**：服务层的聚合搜索、`probe.py`、这次写的
`survey.py` 本身，跑的全是 Null 运行时。quickjs 只在单测里手动注入过。也就是
说 10-16 那张「JS 执行失败 6 / 成功 6」的表来自一个临时脚本，和用户实际会用到
的代码不是同一条路 —— 750 个测试全绿，是因为没有一条断言「JS 真的通过引擎执行
了」。

修法是 `engine/runtime.py`：两个引擎默认用 `engine_js_runtime()`，装了 quickjs
就真执行，没装仍是 Null（显式报错，不静默降级）。补了两条回归测试钉住默认行为。

**第二次**（修完之后，同一批 40 个源）：

```
网络：站点连不上      14  ┐
网络：HTTP 错误码      6  ├ 20 个（50%）源站本身挂了
JS 执行失败          10
跑通但没解析出书       5
成功                 4
WebView              1
```

能连上 20 个，成功 4 个（20%）。和「瓶颈是源站存活率，不是 JS」这个结论仍然
一致 —— 一半源连不上，这次是真的在跑 JS 之后量出来的，不是靠猜。

旧表（规则**静态**可解析率，不是实测，仍保留给历史对比）：

| 档 | 书源 | 订阅源归档 |
| --- | --- | --- |
| 纯规则可跑 | ~63% | 10.6%（142 / 1344） |
| 规则完整但需要 JS | — | 31.8%（427） |
| 接上 quickjs 之后的估计 | ~95% | ~38% |

**这个估计永远不会兑现**，理由不变：它算的是「规则能不能解析」，而一半以上
的源根本连不上。这条和「书源语料大面积失效」是同一件事的两面：**静态可解析率
的提升，最多只有 20%~40% 能转化成实际可用率**（区间来自两次实测：旧的手工
注入脚本测出 37.5%，这次测出 20% —— 差异本身就是样本小、带不确定性的证据，
不是矛盾）。

### 这次「JS 执行失败」里有近一半是同一个缺口：模板里的 `$`

10 个 JS 失败拆开看：

- **5 个 `ReferenceError: '$' is not defined`**——规则形如 `{{$.bookId}}`、
  `{{$.bookid}}`、`{{$.tagList}}`、`{{$.creator.user_id}}`、`{{$.novelId}}`。
  这是 Legado 规则里拿上一步结果当 JSON、用 `$.field` 取值的写法，和 jQuery
  的 `$` 无关。我们的 JS 环境里没有绑定这个全局名字，旧表早就记了「2 个依赖
  我们没有的环境」但只当个例；这次看到的比例（5/10）说明它不是长尾，值得单独
  立一条实现任务：按需要的最小功能绑一个 `$`（JSON 字段取值），不是接入整套
  JSONPath 库。
- 1 个 `java.connect(...)` 链式调用报 `TypeError: not a function` —— 长尾宿主
  方法缺失，按需补。
- 1 个 `importClass is not defined` —— Rhino（Legado 官方引擎）特有的
  Java 类导入语法，quickjs 没有对应物，大概率要显式拒绝而不是实现。
- 2 个 `SyntaxError`（`eval(String(...))`、`@@a.0@href##chapter##book`）——
  后一条是 Legado 的「格式化变量」语法被当成了普通表达式去 eval，不是 JS，这
  又是一个「规则被误判成 JS」的边界问题，和 10-17 修的 `_eval_script` 那个
  bug 是同一类，需要单独查。

这几条都还没修，按「按需补」的既定节奏处理，不在这轮里展开。

同一轮确认过仍成立的旧结论：

- 10-17 修的两个 bug（`_guard()` 把宿主调用失败记进 `SyntaxError` 消息；
  `_eval_script` 不再用 `"return" in body` 猜脚本类型）继续有效，这次的样本
  没有再撞上它们。
- `set_time_limit` 仍与 Python 回调互斥；JS 已移入可终止的子进程，纯计算死循环
  会在 5 秒后被终止。宿主回调仍在父进程执行，单次网络调用受抓取器自身超时约束。

## WebView / 无头浏览器

`singleUrl` 型源占订阅源归档的 21.7%（292 个）。原生 APP 有 WebView 可用，服务端要
支持就得接无头浏览器。我们现在的做法是**显式拒绝**：不列进目录、不让订，当场说明
原因（产品清单的 `R12`）。

hectorqin/reader 给出的边界划法值得照抄：**另起一个容器**
（`hectorqin/remote-webview`），而不是把浏览器塞进主进程。无头浏览器的内存占用和
崩溃率都不该拖垮阅读服务本身。

## `funread/scripts/command.py` 是空壳

整个文件内容被注释掉了，`pyproject.toml` 也没有指向它的 `[project.scripts]` 入口。
如果以后想要一个统一 CLI（而不是让人手写 `python -c "..."` 或者去
`funread-dat/scripts/` 下翻脚本），这里需要重新实现。

## 测试仍以核心数据路径为主

当前规模：funread 758 个、funread-api 228 个，全部离线（注入 `StaticFetcher`）。2026-10-18 新增的主要是 OPML、播客附件、阅读历史、survey.py 的离线分类测试，以及两条钉住「引擎默认真的执行 JS」的回归用例。

**2026-10-17：两个仓库补上 CI 了**（各自的 `.github/workflows/ci.yml`，跑 ruff
+ format + pytest；funread 跑 3.11/3.12 两个版本，3.11 是 requires-python 的
下限）。在那之前两个仓库一条流水线都没有，测试只在本地跑。注意**它拦不住坏
版本发出去** —— `funbuild build` 是从本机直接推 PyPI 的，不经过 CI。

补 CI 时顺带发现：用系统 Python 裸跑是 693 passed + 1 skipped，`uv sync
--all-extras` 装齐之后是 723 passed。**多出来的 29 个用例原先在静默 skip**，
因为 lxml / quickjs 这些按 extra 装的依赖不在，而 skip 是绿的。本地跑测试时
值得留意这个数字。
覆盖了 `storage.py`、数据库配置解析、采集源 API 管理闭环、SQLite WAL 在线备份、
两个引擎的归一化与解析。

没覆盖的是**真实外网采集与远程发布** —— 这两条仍依赖 mock 加手工 smoke test，见
[`project-governance/002-local-development.md`](../../project/project-governance/002-local-development.md)
的「验证 checklist」。

## 「带口令的数据库 URL」是测试照不到的死角

开发和测试一律跑 SQLite，而 **SQLite 的 URL 里没有口令**。于是任何只在「口令写在
URL 里」时才出错的代码，本地全绿、换到 PostgreSQL / MySQL 当场炸。

2026-10-15 真的踩了一次：`accounts.to_async_url()` 把同步 URL 翻成异步驱动时用的是
`str(url)`，而 SQLAlchemy 的 `URL.__str__` 自 1.4 起默认把口令打码成 `***`。翻出来
的串口令字面量就是 `***`，连库必然认证失败。两件事让它格外难查：

- 报错是驱动抛的 `password authentication failed for user "funread"`，**指向凭据，
  不指向这段翻译**。于是排查方向一路跑偏到密钥库里存的口令对不对，而那份口令自始
  至终是对的 —— 拿同一组凭据 `asyncpg.connect()` 直连一直是通的，这反而更坐实了
  「凭据没问题，那就是别的地方」的错误结论。
- 已有的参数化用例写着 `.replace("***", "p")`，**把打码行为当成正确行为钉死了**。
  测试不但没拦住，还站在 bug 那一边：谁把源码改对，谁的测试变红。

两条经验，比这个具体缺陷本身更值得记：

1. 凡是处理数据库 URL 的函数，回归里必须有一条**带口令**的用例，断言口令原样还在。
   现在 `test_the_password_survives_translation` 对两个出口各钉了一条。
2. 测试里出现 `replace`/`strip` 这类**把实际输出"修"成期望值**的写法时，先问一句
   这是在适配什么 —— 很可能适配的就是一个 bug。

## 已经还掉的（留个记录，别再照着旧版本找）

- ~~`funread/web/` 是死代码（nicegui 页面 + `web` extra）~~ —— 目录、extra、依赖都
  已经删掉了。现在 `funread-web` 是唯一的前端，不存在命名混淆。
- ~~`funread-web` 没有生产进程管理方案~~ —— `bin/cli.js` 提供
  `server start|run|restart|stop|status`，外加 `upgrade` / `rollback` /
  `uninstall`。PID 与日志路径跟着 config 走（`server/lifecycle.js`），`uninstall`
  会先 stop 再卸载，不会把活着的服务删掉。
