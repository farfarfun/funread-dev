# 页面布局

逐页记录结构。所有页面共用 `WebLayout` 外壳：顶部 `TopBar`（可选）、内容区、
底部 `TabBar`（可选）。

## 章节目录

| 章节 | 内容 |
| --- | --- |
| [002-shelf-and-search.md](./002-shelf-and-search.md) | 书架、发现（搜索） |
| [003-book-and-reader.md](./003-book-and-reader.md) | 书籍详情、正文阅读 |
| [004-account.md](./004-account.md) | 登录、注册、我的 |

## 外壳的三种形态

| `meta` | 顶栏 | TabBar | 用在 |
| --- | --- | --- | --- |
| （默认） | 有 | 有 | 书架、发现、订阅、我的 |
| `immersive` | 无 | 无 | 正文、文章 |
| `bare` | 无 | 无 | 登录、注册 |

`bare` 和 `immersive` 分开，因为理由不同：前者是「还没有身份，底部导航点进去
全是 401」，后者是「全屏阅读，工具栏由页面自己控制」。
