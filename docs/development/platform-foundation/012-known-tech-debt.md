# 已知技术债 / 限制

核对日期 **2026-10-17**。这一轮实跑了两个测试套件、ruff，并对着代码核对了
JS 那一节的结论 —— **唯一没重跑的是 40 个 needs_js 源的实测**，那张表因此仍是
旧数据，见下。

## JS 规则求值（已接上，但预估需要修正）

**2026-10-16 更新：quickjs 已经接上**（`engine/js/quickjs_runtime.py` +
`host.py`），带 JS 的规则能真执行了。但实测结果和下面这个旧预估差得很远，原因
值得记下来。

旧表（保留原文，它衡量的是**规则静态可解析率**）：

| 档 | 书源 | 订阅源归档 |
| --- | --- | --- |
| 纯规则可跑 | ~63% | 10.6%（142 / 1344） |
| 规则完整但需要 JS | — | 31.8%（427） |
| 接上 quickjs 之后的估计 | ~95% | ~38% |

实测（挑 40 个 needs_js 且规则完整的书源，搜索链路全部带 JS）：

```
网络：站点连不上      14  ┐
网络：HTTP 错误码      5  ├ 23 个（58%）源站本身挂了
网络：其它            4  ┘
JS 执行失败           6
成功                 6
跑通但没解析出书       4
WebView              1
```

**瓶颈不是 JS，是源站存活率。** 接 JS 之前能连上的 16 个源里成功 4 个，之后
6 个 —— 25% → 37.5%，是真实的提升，但「63%→95%」那个数字永远不会兑现，因为
它算的是「规则能不能解析」，而一半以上的源根本连不上。

这条和「书源语料大面积失效」是同一件事的两面，评估任何引擎侧改进时都要先扣掉
这个底：**静态可解析率的提升，最多只有 40% 左右能转化成实际可用率。**

### 还差什么

按实测频率实现了前 20 几个宿主 API（归档里 209 个不同方法，前 10 个覆盖 75.8%
的调用）。剩余 6 个失败分三类：

- 2 个缺长尾方法 —— 按需补即可，有现成的实现位置；
- ~~2 个 `SyntaxError: unexpected end of input` —— **疑似我们提取 JS 片段时截断
  了**，这个值得单独查~~ **查清了，而且这个猜测是错的，没有任何截断。**
  真正的原因是宿主调用（典型是 `java.ajax`）失败返回空串，规则接着拿它去
  `JSON.parse("")` —— 那个 `SyntaxError` 是 quickjs 对空输入的报错，和「谁让它
  空的」隔了一层，所以看起来像我们截断了脚本。已修：`_guard()` 把本次求值期间
  失败的宿主调用记下来，抛错时附在消息后面（`js/quickjs_runtime.py:243`）。
- 2 个依赖我们没有的环境（规则里用 `$`）。

同一轮还修掉一个**我们自己的** bug，它当时被误算进「源的规则有问题」：
`_eval_script` 原先用 `"return" in body` 猜脚本是表达式还是语句块，而
`var s = "returned"; s` 里的 `return` 只是字符串的一部分。40 个样本里有 7 个栽
在这上面（`js/quickjs_runtime.py:268` 的模块注释有完整经过）。现在交给引擎自己
判断。

**所以上面那张实测表是修这两处之前的数据，偏悲观，需要重测。** 这也是个教训：
失败分类里凡是写着「疑似」的，在重测之前都不该当成结论引用。

另有一条绑定本身的硬限制写在 `quickjs_runtime.py` 的模块文档里：`set_time_limit`
与 Python 回调互斥，所以**没有执行时间上限**，纯计算死循环挡不住。

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

当前规模：funread 723 个、funread-api 223 个，全部离线（注入 `StaticFetcher`）。

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
