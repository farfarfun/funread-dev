# 发布与进程入口约定

本章记录本工作区怎么分类应用、怎么起停服务、怎么构建发布。约定来自
`farfarfun-skill--service-governance` 的 `submodule-workspace-governance`、
`service-release-governance` 与 `bash-service-guide` 三个 skill，这里只写落到
funread 上的具体结论。

## 应用分类

每个 `apps/<name>` 恰好属于一类，**由它实际做什么决定，不从仓库名后缀推断**。
分类必须在两处保持一致：根 `scripts/setup.sh` 的 `resolve_service_app()` /
`resolve_package_app()`，以及 `README.md` 的应用表格。两处不一致是缺陷。

| 别名 | 路径 | 类别 | 判定依据 |
| --- | --- | --- | --- |
| `api` | `apps/funread-api` | service | uvicorn 把它当长驻 HTTP 进程启动 |
| `web` | `apps/funread-web` | service | 生产态有自己的 Node 服务器，既发静态资源又反代 `/api` |
| `core` | `apps/funread` | package | 只会被 `import` / `pip install` 成依赖，没有进程 |
| `dat` | `apps/funread-dat` | package（退化） | 没有进程，也不发布成可安装包，见下 |

`funread-dat` 是数据仓库：5 个胶水脚本 + `hubs/` 下的数据快照，`pyproject.toml` 里
标了 `[tool.uv] package = false`。它登记在 `resolve_package_app` 里（别名 `dat`），
但只有 `install-dev` 有实际含义；`install-prod` / `upgrade` / `rollback` 依赖
「索引上有正式包」这个前提，对它不成立，所以它自己的 `scripts/setup.sh` 对这几个
action 显式报错，而不是假装成功。`funbuild build` 也会跳过它。

本工作区目前**没有** nested workspace 类应用。

## action 分两组

根 `scripts/setup.sh <action> <target>` 是唯一的跨仓库入口。两组 action 的 `all`
含义不同 —— 这是这套模式里最容易搞混的地方：

| 组 | action | `all` 展开为 |
| --- | --- | --- |
| service | `start` `stop` `restart` `run` `status` | 仅 service app：`api web` |
| release | `install-dev` `install-prod [version]` `upgrade [version]` `rollback <version>` | service + package app：`api web core dat` |

- **`build` / `publish` 不是 `setup.sh` 的 action。** 构建发布由仓库根的
  `funbuild build` 自己 fan out（它认 `apps/` + `scripts/funbuild.toml` 这个布局），
  `scripts/build.sh` 因此只有一行 `exec funbuild build`。
- 对分组外的目标执行 action（例如 `start core`）是**用法错误，必须大声失败**，
  不能静默跳过。
- 缺 `<action>` 或 `<target>` 时退回 `gum choose` 交互菜单；参数写全的调用永远
  不碰 `gum`，在 CI 里行为一致。`rollback` 缺版本号时直接报错，不进菜单 ——
  回滚没有可交互的默认值。
- 多 app 时按脚本里 `ALL_SERVICE_APPS` / `ALL_RELEASE_APPS` 的声明顺序处理；
  `set -e` 下第一个失败即中止，不继续处理后面的 app。
- service action 一律转发给目标 app 自己的 `scripts/setup.sh <action>`，
  **dev 仓库层面不重新实现 PID / 端口 / 进程管理**。

## CLI Entrypoint Contract

两个 service app 各暴露一个命名 CLI，形状相同：

```
<cli> server start|run|stop|status      # 服务生命周期
<cli> upgrade [version]                 # 顶级，不在 server 组里
<cli> rollback <version>
<cli> uninstall
```

| | funread-api | funread-web |
| --- | --- | --- |
| CLI 名 | `funread-api` | `funread-web` |
| 声明处 | `pyproject.toml` 的 `[project.scripts]` | `package.json` 的 `bin` |
| 默认端口 | `18811` | `8811` |
| 默认 config | `${XDG_CONFIG_HOME:-~/.config}/farfarfun/funread-api/config.toml` | `${XDG_CONFIG_HOME:-~/.config}/farfarfun/funread-web/config.toml` |
| PID 文件 | `funread-api.pid` | `funread-web.pid` |

- **没有 `<cli> install` 子命令。** CLI 没装上之前自己装不了自己；首装走
  `pip install` / `npm install -g` / `funbuild install`，由各 app 的
  `scripts/setup.sh` 的 `install-dev` / `install-prod` 承担。
- `--config` 按扩展名选 parser（`.json` / `.toml` / `.env`）。
- **PID 文件写在实际解析到的 config 同目录下**，不是某个固定的 state 目录 ——
  这样一台机器上跑多份实例时，配置和运行时状态总是成对的。
- `--port` 等离散 flag 覆盖 config 文件里的同名键。
- `status` 要报告已安装包的版本，不只是进程是否活着。
- `stop` 内部走 `funshell port <port> --kill`。`funread-api` 是 Python，直接依赖
  `funshell` 包在进程内调用；`funread-web` 不是 Python，shell out 到 `funshell` 命令。
- **`start` 由 CLI 自己后台化，`run` 前台 `exec`。** Bash 脚本不 `nohup`、
  不写 PID 文件、不轮询存活 —— 那些都是 CLI 的责任。

### 当前实现与契约的对照（M3b 之后）

两个 service app 的 CLI 都已落地，形状对得上契约：

| | funread-api | funread-web |
| --- | --- | --- |
| 实现 | `src/funread_api/cli.py` | `bin/cli.js`（Node 标准库，不引 express） |
| 子命令 | `server run\|start\|restart\|stop\|status` + 顶级 `upgrade`/`rollback`/`uninstall` | 同形 |
| `--config` | 有，按扩展名选 `.json`/`.toml`/`.env` parser | 同 |
| PID 文件 | 实际解析到的 config 同目录（`Settings.state_dir`） | 同 |
| `status` 报版本 | 有 | 有 |

剩下一处**故意的偏离**，不是待办：契约写的是「`stop` 内部走
`funshell port <port> --kill`」，实现是**先 PID 后端口**——
`_stop_server()` 读到活着的 PID 就先用 `_pid_belongs_to_service()` 核对
`/proc/<pid>/cmdline` 再发 SIGTERM，只有 PID 文件丢了或过期（含旧版写在
`cwd()/.run/` 下的那种）才退到 `_kill_by_port()`。理由是按端口杀会命中「任何占着
这个端口的进程」，而按 PID 杀能先确认那是不是我们的服务；反过来只按 PID 杀则救
不回 PID 文件丢失的场景，所以两条都要留。两条路径发的都是 SIGTERM 而不是
SIGKILL —— uvicorn 需要跑完自己的 shutdown handler。

### 发布顺序约束

`funread-api` 依赖 `funread[reader]`。这条依赖在 1.1.104 之前是断的（索引上的
funread 1.1.103 只有 `['dev', 'web']` 两个 extra，装完 CLI 在 `import` 处就崩），
现在已经解开：1.1.104 起 `reader` / `parse` 两个 extra 都在索引上。

约束本身仍然成立 ——**不要单独发 funread-api**。正确做法是从 dev 仓库根跑一次
`scripts/build.sh`（即 `funbuild build`）：它用 `scripts/funbuild.toml` 里的共享
版本号把 `apps/` 下所有应用一起发出去，两者的版本自然对齐。只要 funread-api 用到
了 funread 里尚未发布的新 API（这在同一轮改动里横跨两个仓库时很常见），单独发
就会让装正式包的环境在那个新端点上崩。

还有一条踩过的坑：`[tool.funbuild]` 的 `latest-packages = ["funread"]` 本意是发版时
把 funread 的版本下界抬到最新，但它查索引的时机早于新版传播完成，解析到的是**上
一版**。所以每次发完都要回头确认一次 `funread-api/pyproject.toml` 里的下界，必要时
补一个 commit（1.1.104 那轮就是这么补的）。

## funread-web 的反代要求

`funread-web` 的生产态服务器做两件事，不是一件：按 base path 发构建产物，
**并把所有面向后端的路径（`/api/**`、`/healthz`）反代到 `funread-api`**。

两者分开部署之后这不是可选项：没有反代，浏览器会直接打 `funread-api` 然后撞
CORS，而 `funread-api` 刻意不挂 CORS 中间件。**不要反过来给 `funread-api` 加
CORS** —— 那等于把后端对任意 origin 放开，而且和反代重复了同一个职责。

后端地址的解析优先级和 Entrypoint Contract 其余部分一致：
`--backend` flag > config 文件字段 > `FUNREAD_API_BASE_URL` 环境变量 >
硬编码本地默认值 `http://127.0.0.1:18811`。**`vite.config.ts` 的 dev 代理必须指向
同一个环境变量**，否则 `pnpm dev` 和打包后的 CLI 会是两套漂移的代理配置。

路由不许有歧义：反代路径永远不落到 SPA 的 `index.html` fallback，静态资源路径
永远不走反代。

## 版本与构建

`scripts/funbuild.toml` 声明 `apps/` 下所有应用共享的版本号，`funbuild build`
读它、递增它，让所有 app 以同一个版本号发布，而不是各自记一套。这个文件要提交；
`funbuild` 会在每次构建时原地改写它。

构建发布的完整链路：

```bash
bash scripts/build.sh      # == exec funbuild build
#   1. 递增 scripts/funbuild.toml 的 version
#   2. 用这个版本构建并发布 apps/ 下每个非 nested-workspace 应用
#   3. 最后在 dev 仓库 commit / push / tag 一次，让所有子模块指针一起落地
```

注意 `funbuild push` 在最后**只跑一次**，不是每个 app 跑一次 —— 这样 dev 仓库的
历史读起来是「第 N 版指向这几个 commit」，而不是一串互不相关的单 app 指针变更。

## 子模块提交顺序

子模块指针和应用仓库的 commit 是两个仓库里的两个 commit，**绝不允许一个动了
另一个没动**：

1. 在 `apps/<name>` 里改、commit，并**先 push 到该应用自己的 remote**。
2. 回 dev 仓库根 `git add apps/<name>`（多个应用一起改就一次 `git add` 全部），
   commit、push。
3. 不要在 dev 仓库层面改 `apps/<name>` 里的文件然后只在 dev 仓库 commit ——
   那个改动属于应用仓库。
4. 拉取所有应用的最新代码用 `git submodule update --remote`，然后重复第 2 步
   把结果记下来。

## 验证清单

改动任何脚本或入口后跑一遍：

```bash
bash -n scripts/setup.sh scripts/build.sh scripts/init.sh
bash -n apps/*/scripts/setup.sh

./scripts/setup.sh                     # 不带参数：gum 菜单（没装 gum 则报错退出）
./scripts/setup.sh start core          # 必须报错：service action 打到 package app
./scripts/setup.sh rollback api        # 必须报错：缺版本号
./scripts/setup.sh status all          # 逐个转发给 api / web 自己的脚本

git submodule status                   # 不应有预期外的 + 或 - 前缀
```
