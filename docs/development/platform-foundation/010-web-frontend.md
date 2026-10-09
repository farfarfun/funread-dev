# 前端(`funread-web/`)


从空仓库(只有一个 README)搭的最小 Vite + Vue3 + TS 单页:

```
funread-web/
├── package.json        # Vue、Naive UI、Ionicons 与 Vite 工具链
├── index.html
├── src/
│   ├── api/              # 同源 API 客户端与类型
│   ├── styles/tokens.css # 与 funflix-web 一致的主题/可访问性基础变量
│   ├── views/SourcesView.vue # 筛选、排序、批量操作、分页与登记弹窗
│   ├── App.vue           # Naive UI 主题与 Provider
│   └── main.ts
├── vite.config.ts        # 前端固定 8811;/api、/healthz 内部转发到后端 18811
└── pnpm-workspace.yaml   # allowBuilds: esbuild: true(见 project-governance/002-local-development.md 的 pnpm 坑)
```

采集源页直接复用 funflix-web 的 Naive UI 交互模式:全量排序、行/批量选择、四路操作队列、筛选、分页、登记弹窗和深浅主题。没有引入 `vue-router`(只有一个页面)。开发服务与构建预览固定在 `8811`,把同源 `/api`、`/healthz` 转发到 `FUNREAD_API_BASE_URL`(默认 `http://127.0.0.1:18811`)。
