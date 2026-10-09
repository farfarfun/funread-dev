# 手工与端到端走查

## 全栈端到端（已执行）

起真的 `funread-api`（18898）与 `funread-web server start`（18899，反代到前者），
对真实的 1,344 个源归档，按顺序走通：

| 步骤 | 结果 |
| --- | --- |
| `/` 重定向 | 302 → `/web` ✓ |
| 八个页面可达 | `/web`、`/web/search`、`/web/rss`、`/web/account`、`/web/login`、`/web/register`、`/admin/sources`、`/admin/login` 全 200 ✓ |
| 反代 `/healthz` | `{"status":"ok"}` ✓ |
| 首次运行探测 | `/auth/me` 返回 `local=true, user_id=0`；`/auth/accounts` 返回 `users=0` ✓ |
| 注册（带邀请码） | 201，`user_id=1`，`local=false` ✓ |
| 邀请码错 | 403 ✓ |
| 扫 rss 候选池 | `scanned=1344 complete=547 needs_js=427 web_view=292 enabled=142` ✓ |
| 订阅源目录 | `total=142`，首项「SF漫画」带 12 个分类与图标 ✓ |
| 贴错 feed 地址 | 400 +「无法解析为 XML，可能不是 feed 地址」✓ |
| 订阅归档源 | 201，12 个分类 ✓ |
| 订阅真实 feed | Hacker News，`preview=30` ✓ |
| 文章列表 | 4 篇，`has_content=true` ✓ |
| 标已读 | 204，`read_count` 变 1 ✓ |
| 收藏 | 204，收藏列表可见 ✓ |
| 文章正文 | 标题与正文都拿到 ✓ |
| 退订 | 204 ✓ |

### 期间发现并确认的两件事

**1. 一个归档源返回 0 篇文章。** 订阅「SF漫画」后文章列表是空的、`has_content=false`。
这是**源站的事**，不是代码问题 —— 和已知风险「书源语料大面积失效」同源。重要的是
它返回了格式正确的空页加 `has_content=false`，界面按设计显示空态与外跳提示，没有崩。

**2. `ruanyifeng.com/blog/atom.xml` 返回 403。** 那个站拒绝我们的 UA。错误原样
透出（`HTTP 403 | url=... | status=403`），用户能看懂发生了什么。换 Hacker News
的 feed 一次成功。

## 服务生命周期（已执行）

| 项 | 结果 |
| --- | --- |
| `funread-api server start/status/stop` | ✓，PID 文件在 config 旁边 |
| **换目录 stop** | ✓ —— 这是本轮修掉的回归（原来 PID 跟着 `cwd` 走，换目录就停不掉） |
| `funread-web server start/status/stop` | ✓ |
| 反代 `/api` 与 `/healthz` | ✓，路径含 query 原样转发、Host 改写、POST body 透传 |
| 后端挂掉时 | 502 带原因，不是白屏 ✓ |
| 目录穿越 | `/../../etc/passwd`、`/%2e%2e/...` 全被拒 ✓ |
| 根 `scripts/setup.sh` 的错误路径 | `start core`、`rollback` 缺版本、未知 action 全 exit=2 带中文说明 ✓ |

## 真机走查（未执行）

以下需要手机实机，**本轮未做**，列在这里作为待办：

- iPhone / Android 真机：安全区（底部 TabBar 不被手势条压）、`100dvh`（地址栏
  伸缩时 TabBar 不跑出屏幕）、输入框不触发自动放大；
- 正文页手势：左右边缘翻章的触控带宽度是否顺手；
- 长目录（三千章以上）的虚拟滚动在低端机上的实际帧率；
- 飞行模式下读已下载章节；
- PWA 装到桌面后的启动表现。

这些都是**测不出来**的那一类（真机行为、手感、帧率），只能实机过。DevTools 的
iPhone SE / Pixel 视口模拟可以先排掉横向滚动和明显的布局破裂，但不能替代真机。
