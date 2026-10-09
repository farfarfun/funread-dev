# 设计底座

## 令牌

分两层，故意不合并：

- `src/styles/tokens.css`：与主题无关的量 —— 间距阶梯（4/8/12/16/24/32）、
  缓动曲线、焦点环。
- `src/styles/web.css`：跟着明暗主题翻转的语义色 —— `--surface-raised`、
  `--surface-sunken`、`--border-subtle`、`--text-muted`、`--accent`。

用 CSS 变量而不是 Naive UI 的 theme 变量，因为自写组件（TabBar、ArticleCard、
SkeletonList…）不走 Naive 的 provider 链，拿不到它的 theme 注入。

主题色 `#6D5EF8`。深色模式下 `--accent` 提亮到 `#8B7FFA` —— 同一个紫在深底上
对比度不够。

## 安全区

三处必须让开系统占用的区域，少一处就会在真机上被压掉：

| 位置 | 处理 |
| --- | --- |
| `index.html` 的 viewport | `viewport-fit=cover`。**没有它，`env(safe-area-inset-*)` 恒为 0**，下面两条全都白写 |
| TabBar / 正文工具栏 | `padding-bottom: env(safe-area-inset-bottom)` |
| TopBar 横屏 | `padding-inline: max(var(--space-3), env(safe-area-inset-left/right))` |

## 视口高度

一律 `100dvh`，不用 `100vh`。移动浏览器的地址栏会随滚动伸缩，`vh` 取的是最大
值，于是底部被截掉一截 —— 表现为「TabBar 一半在屏幕外」。

## 触控尺寸

`@media (pointer: coarse)` 下 `.n-button`、`.n-input` 最小 44×44。自写的可点元素
（TabBar 的 tab、ArticleCard 的收藏星）也按这个下限写死。

44px 不是装饰：收藏星和整条卡片的点击区挨在一起，小于这个尺寸就会误触。

## 输入框字号

移动端 `input/textarea/select` 的 `font-size` 用 `max(16px, 1em)`。iOS Safari 在
字号小于 16px 时会自动放大页面，把整个布局顶歪，而且不会自己缩回去。

## 横向滚动

`html, body { overflow-x: hidden }`。移动端最常见的布局 bug 是某个元素撑破视口，
导致整页能左右拖动。需要横滚的地方单独处理：分类条、表格、代码块各自 `overflow-x`。

## 正文配色与应用主题是两件事

应用外壳（列表、卡片、按钮）跟 Naive UI 的明暗主题走；正文底色由读者在阅读设置
里单独选（纸白 / 夜间 / 护眼）。深色外壳配纸白正文是很常见的搭配，强行统一只会
两边都不合用。
