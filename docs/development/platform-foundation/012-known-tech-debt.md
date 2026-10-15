# 已知技术债 / 限制

核对日期 **2026-10-15**。

## JS 规则求值（最大的一笔）

书源可解析率 ~63%、订阅源归档可跑率 10.6% 的天花板全在这一条上。Legado 的规则语言
允许在规则里写 JavaScript，并给了一整套 `java.*` 宿主 API（`java.ajax`、
`java.getCookie`、`java.cache`、`java.base64Decode`…）。我们的引擎是纯 Python 的，
遇到带 JS 的规则只能跳过。

| 档 | 书源 | 订阅源归档 |
| --- | --- | --- |
| 纯规则可跑 | ~63% | 10.6%（142 / 1344） |
| 规则完整但需要 JS | — | 31.8%（427） |
| 接上 quickjs 之后的估计 | ~95% | ~38% |

这是**单项投入回报最高的一件事**：订阅源那 427 个「规则完整，只差一个 JS 引擎」的
源里大部分会直接活过来。真正要做的功课不是接 quickjs 本身（有现成的 Python 绑定），
而是**把那套宿主 API 的清单与语义补全** —— 语义对不上的话 JS 跑得起来结果也是错的。
`LegadoTeam/legado` 对宿主 API 的实现是直接参考，见
[`013-reference-implementations.md`](./013-reference-implementations.md)。

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

当前规模：funread 652 个、funread-api 187 个，全部离线（注入 `StaticFetcher`）。
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
