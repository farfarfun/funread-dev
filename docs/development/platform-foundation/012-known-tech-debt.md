# 已知技术债 / 限制


- **`funread/scripts/command.py` 是空壳**:整个文件内容被注释掉了,`pyproject.toml` 也没有指向它的 `[project.scripts]` 入口。如果以后想要一个统一 CLI(而不是让人手写 `python -c "..."` 或者去 `funread-dat/scripts/` 下翻脚本),这里需要重新实现。
- **`funread/web/` 是死代码**:nicegui 页面,`pyproject.toml` 里的 `web` extra 对应它,但没有任何入口调用/启动它。和这次新加的 `funread-web`(独立的 Vite 前端仓库)是两个不相关的东西,命名容易混淆,需要留意别搞反了。
- **测试范围仍以核心数据路径为主**:`funread/tests/` 已覆盖 `storage.py`、数据库配置、采集源 API 管理闭环和 SQLite WAL 在线备份;真实外网采集与远程发布仍依赖 mock 和手工 smoke test(见 project-governance/002-local-development.md 的"验证 checklist")。
- **`funread-web` 没有生产进程管理方案**:`pnpm dev` 与 `pnpm preview` 已能同源反代 API,但还没有 funflix-web 的安装包、PID/日志和 start/stop/restart CLI。
