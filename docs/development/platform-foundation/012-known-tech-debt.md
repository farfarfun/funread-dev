# 已知技术债 / 限制

核对日期 **2026-10-10**。

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

## 已经还掉的（留个记录，别再照着旧版本找）

- ~~`funread/web/` 是死代码（nicegui 页面 + `web` extra）~~ —— 目录、extra、依赖都
  已经删掉了。现在 `funread-web` 是唯一的前端，不存在命名混淆。
- ~~`funread-web` 没有生产进程管理方案~~ —— `bin/cli.js` 提供
  `server start|run|restart|stop|status`，外加 `upgrade` / `rollback` /
  `uninstall`。PID 与日志路径跟着 config 走（`server/lifecycle.js`），`uninstall`
  会先 stop 再卸载，不会把活着的服务删掉。
