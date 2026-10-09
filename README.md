# funread-dev

funread 联合开发仓库，通过 Git 子模块固定各子项目的版本。

## 项目

| 目录 | 别名 | 类别 | 项目 | 说明 |
| --- | --- | --- | --- | --- |
| `apps/funread` | `core` | package | [funread](https://github.com/farfarfun/funread) | 核心领域库：规则引擎、阅读服务层、采集源数据模型与采集管线 |
| `apps/funread-api` | `api` | service | [funread-api](https://github.com/farfarfun/funread-api) | 后端服务，依赖 `funread` 并对外暴露采集源管理与阅读 HTTP API |
| `apps/funread-web` | `web` | service | [funread-web](https://github.com/farfarfun/funread-web) | 前端服务：`/admin` 采集源管理端与 `/web` 阅读端，运行时反代 `/api` 到 `funread-api` |
| `apps/funread-dat` | `dat` | package（退化） | [funread-dat](https://github.com/farfarfun/funread-dat) | 数据仓库：初始化、登记采集源、备份与上传脚本 + 数据快照 |

「类别」决定哪些 action 对它有效，见下文「服务生命周期」与「安装 / 升级」。这一列必须与
`scripts/setup.sh` 里的 `resolve_service_app()` / `resolve_package_app()` 一致 ——
两处不一致是缺陷。分类依据与 `funread-dat` 为什么是「退化」见
[发布与进程入口约定](docs/project/project-governance/003-release-and-entrypoint.md)。

具体的安装、配置和开发方式见各子项目 README；跨仓库的开发流程见
[本地开发](docs/project/project-governance/002-local-development.md)。

## 获取代码

首次克隆时同时拉取子模块：

```bash
git clone --recurse-submodules https://github.com/farfarfun/funread-dev.git
cd funread-dev
```

已有仓库（或未使用 `--recurse-submodules` 克隆）可执行：

```bash
bash scripts/init.sh
```

## 更新子模块

```bash
git submodule update --remote
git add apps/funread apps/funread-dat apps/funread-api apps/funread-web
```

更新后的子模块提交由当前仓库记录，需要随父仓库一起提交。

## 跨仓库入口

统一入口是 `scripts/setup.sh <action> <target>`，它只做分发 —— 转发给
`apps/<name>/scripts/setup.sh <action>`，不在本仓库重新实现进程或安装逻辑。

action 分两组，**两组的 `all` 含义不同**：

```bash
# 服务生命周期：只对 service 类有效，all = api web
bash scripts/setup.sh start all
bash scripts/setup.sh status api
bash scripts/setup.sh stop web
bash scripts/setup.sh run api                 # 前台运行，Ctrl-C 结束

# 安装 / 升级：对 service + package 都有效，all = api web core dat
bash scripts/setup.sh install-dev all         # 从工作树构建并本地安装
bash scripts/setup.sh install-prod api 1.2.3  # 从索引装指定版本，省略版本=最新
bash scripts/setup.sh upgrade all
bash scripts/setup.sh rollback api 1.2.2      # 版本号必填

bash scripts/setup.sh                         # 不带参数：gum 交互选 action/target
```

对分组外的目标执行 action（例如 `start core` —— `funread` 是 package 类，没有进程）
会直接报错退出，不静默跳过。

不带参数、或漏传 `target` 时，脚本会用 [`gum`](https://github.com/charmbracelet/gum)
弹交互菜单补全缺的部分；没装 `gum` 就必须把参数写全，脚本本身不负责装这个交互依赖。
`rollback` 漏版本号时直接报错而不是进菜单 —— 回滚没有可交互的默认值。

## 构建 / 发布

**`build` / `publish` 不是 `scripts/setup.sh` 的 action。** 构建发布由本仓库根的
`funbuild build` 自己 fan out（它认 `apps/` + `scripts/funbuild.toml` 这个布局）：

```bash
bash scripts/build.sh      # 等价于 funbuild build
```

它递增 `scripts/funbuild.toml` 的共享版本号，用这个版本构建并发布 `apps/` 下每个可发布
应用（跳过 `funread-dat`，它标了 `package = false`），最后统一执行一次 `funbuild push`，
把更新后的子模块指针作为一次提交推送。

两个 service 应用各暴露一个命名 CLI（`funread-api` / `funread-web`），形状为
`<cli> server start|run|stop|status` 加顶级 `upgrade` / `rollback` / `uninstall`；
`scripts/setup.sh` 的 service action 就是转发到这里。契约细节（config 解析顺序、PID
文件位置、`funread-web` 的反代要求）见
[发布与进程入口约定](docs/project/project-governance/003-release-and-entrypoint.md)。

## 文档

从 [项目总览](docs/project/project-overview.md) 开始 —— 它是文档入口，含完整索引。
