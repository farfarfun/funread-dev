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

## 手机尺寸视口走查（已执行，2026-10-10）

起生产构建的 `funread-web`（18899，反代到 18898 的真 `funread-api`），用真账号
登录后逐页扫。**不是 DevTools 手点**，是脚本化的量测 —— 每一页都读
`getBoundingClientRect` 和 `getComputedStyle`，所以每条结论背后都有具体数字，
而不是「看着还行」。

| 维度 | 配置 |
| --- | --- |
| 浏览器 | Chrome for Testing 143（headless，Playwright 驱动） |
| 视口 | 320×568 @2x、375×667 @2x、393×852 @3x、412×915 @2.625x |
| 上下文 | `is_mobile` + `has_touch` + iOS 17 Safari UA |
| 页面 | 书架 / 发现 / 搜索 / 订阅 / 订阅源目录 / 收藏 / 文章列表 / 书籍详情 / 我的 / 登录 / 注册 / 文章正文，共 12 × 4 = 48 次 |
| 数据 | 6 本书分 2 组（玄幻 3 / 未分组 3）、1 个真实 feed（Hacker News，30 篇） |

320 那档是现存最窄的在用尺寸（iPhone SE 1 / 小屏安卓），布局破裂先在它身上出现。

### 查了什么

横向溢出（`scrollWidth - clientWidth`，并列出真正戳出右边界的元素）、固定定位条
是否跑出视口、样式里有没有真的用上 `safe-area-inset`、点击目标尺寸、正文字号、
**输入框字号**（< 16px 时 iOS Safari 会自动放大整页）、加载期间的 4xx/5xx 与
console error。

### 查出来并修掉的五件事

**1. 防 iOS 自动放大的那条规则是死的。** `web.css` 里有一条看着没问题的
`@media (max-width: 768px) { input { font-size: max(16px, 1em) } }`，但登录页量到
的仍是 14px —— naive-ui 把字号写在 `.n-input__input-el` 上，而且样式是运行时注入
的，在层叠里排在本文件之后，裸 `input` 选择器打不过它。把 naive 自己的类名点进来
并加 `!important` 后，12 个页面的输入框全部 ≥ 16px。**这类 bug 只有量渲染结果才
能发现**，读代码读不出来。

**2. 书架分组胶囊 31px 高。** 横滚条里的分组标签，`tokens.css` 那条
`@media (pointer: coarse) .n-button { min-height: 44px }` 管不到（它不是
`n-button`）。改成 `min-height: 36px`、粗指针下 40px —— 44 在横滚条里太高，会把
书架整体推下去。

**3. 登录/注册页的行内链接命中区只有 17px。** 「用邀请码注册」「管理端登录」这类
文字链的可点区域就是一个行框高。改成 `inline-block` + `min-height: 44px`，视觉上
仍是一行文字。（中途只加 padding 凑到 35px，不够，再补的 `min-height`。）

**4. 顶栏返回键 36×36。** 同样不是 `n-button`。改成 44×44，负 margin 跟着从 -6
放大到 -10，让图标左边缘停在原位，标题间距不变。

**5. 文章卡片把源站 HTML 当文字显示了。** Hacker News 的 `description` 是
`<a href="https://news.ycombinator.com/item?id=...">Comments</a>`，`{{ }}` 插出来
就是两行尖括号，在 320px 宽的卡片上等于整条摘要全废。改成用 `<template>.content`
取纯文字（游离片段，不触发资源加载也不执行脚本，顺带解实体）。同一条还顺手修了
时间：RFC-822 原串 29 个字符要吃掉整行，改成一周内相对时间、更早显日期；
meta 字号 11px → 12px。

### 修完的结果

48 次量测里：

- **横向溢出 0**，四个宽度、十二个页面全部 `scrollWidth == clientWidth`；
- 每一页的样式里都解析得到 `safe-area-inset`；
- TabBar 固定在 53px、底边贴着视口下沿，没有一页跑出去；登录/注册是 `bare` 路由，
  正确地没有 TabBar；
- 输入框字号全部 ≥ 16px；
- 正文字号没有一处 < 12px；
- 点击目标只剩一处低于阈值：**源站正文里的内联 `<a>`（92×26）**。那是消毒后保留
  的源站内容，不是我们的控件 —— 对任意源站的 prose 强行撑到 44px 会把排版打烂，
  这一条是**接受**，不是遗漏。

扫描期间唯一的 4xx 是 `/reader/book?url_id=6&…` 的 404：种子书架用的是构造出来的
假书（源不存在），详情页正确地渲染成「打不开这本书」错误态而不是白屏。之前常驻的
那条根 `/favicon.ico` 404 已经消失 —— `index.html` 补了 `rel="icon"` 与
`rel="apple-touch-icon"`（后者是一张 180×180 PNG：iOS 的「添加到主屏幕」既不读
manifest 的 `icons` 也不认 SVG，缺这张图会拿网页截图当图标）。

### 这种走查覆盖不到的（仍然只能实机过）

视口模拟换不来真机，下面这些本轮**依然没有数据**：

- `env(safe-area-inset-*)` 的**真实数值**。桌面 Chromium 下它恒等于 0，所以这里
  只能验「样式里用了没」，验不了「刘海和手势条真的让开了没」；
- `100dvh` 在地址栏伸缩时的实际行为（移动 Safari 的工具栏收起/展开）；
- 手感：正文页左右边缘翻章的触控带宽不宽、点下去跟不跟手；
- 长目录（三千章以上）虚拟滚动在低端机上的真实帧率；
- 飞行模式下读已下载章节；
- PWA 装到主屏后的冷启动表现（图标这一环已经补上，启动表现没验）。
