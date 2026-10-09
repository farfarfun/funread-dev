# 阅读端 UI 交接

移动优先。所有尺寸、间距、断点都以手机竖屏为基准，桌面只是「更宽的手机」。

## 章节目录

| 章节 | 内容 |
| --- | --- |
| [002-foundation.md](./002-foundation.md) | 设计令牌、安全区、触控尺寸这些底座约定 |
| [pages/001-overview.md](./pages/001-overview.md) | 逐页布局 |
| [flows/001-overview.md](./flows/001-overview.md) | 关键流程 |
| [states/001-overview.md](./states/001-overview.md) | 加载、空、错误三类状态的统一处理 |

## 为什么没有设计稿文件

这一版没有 Figma 源文件 —— 界面是直接用 Naive UI 的组件拼的，设计决策全部落在
代码和本包的文字里。`screens/`、`assets/` 这些目录留空而不是硬塞占位图。

真要出设计稿时，`docs/design/reader-client/screens/` 是约定路径。
