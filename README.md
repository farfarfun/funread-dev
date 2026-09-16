# funread-dev

funread 联合开发仓库，通过 Git 子模块固定各子项目的版本。

## 项目

| 目录 | 项目 | 说明 |
| --- | --- | --- |
| `apps/funread` | [funread](https://github.com/farfarfun/funread) | 核心领域库，采集源数据模型与业务逻辑 |
| `apps/funread-dat` | [funread-dat](https://github.com/farfarfun/funread-dat) | 数据层脚本：初始化、登记采集源、备份与上传 |
| `apps/funread-api` | [funread-api](https://github.com/farfarfun/funread-api) | 后端服务，依赖 `funread` 并对外暴露 API |
| `apps/funread-web` | [funread-web](https://github.com/farfarfun/funread-web) | 采集源管理前端界面，反向代理请求到 `funread-api` |

具体的安装、配置和开发方式见各子项目 README。

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

## 构建 / 发布

统一入口是 `scripts/setup.sh <action> <target>`：

```bash
bash scripts/setup.sh build all      # 或 build api / build web / build funread
bash scripts/setup.sh                # 不带参数：装了 gum 的话交互选 action/target
```

`build` 覆盖 `funread`、`funread-api`、`funread-web`（不含 `funread-dat`——它不是要发布的
Python 包，`uv` 里标了 `package = false`，只是一堆脚本，改完直接在它自己仓库里
`commit + push` 就行，不需要 `funbuild build`）。依次切到 `master`、执行 `funbuild build`，
最后统一执行一次 `funbuild push`，把更新后的子模块指针作为一次提交推送。`scripts/build.sh`
等价于 `scripts/setup.sh build all`。

`start`/`stop`/`restart`/`run`/`status`/`install`/`publish` 只对 CLI-bearing 的
`api`（`funread-api`）、`web`（`funread-web`）生效，`all` 表示这两个，脚本会转发到对应子
项目自己的 `scripts/setup.sh <action>`。**目前 `funread-api`、`funread-web` 还没有各自的
`scripts/setup.sh`**，这几个 action 暂时不可用，等两个仓库补上各自的服务生命周期脚本
（start/stop/restart/run/status，带 PID/端口管理）后才会生效；在此之前，按各子项目 README
手动启动。

不带参数、或漏传 `target` 时，脚本会用 [`gum`](https://github.com/charmbracelet/gum)
弹交互菜单补全缺的部分（参考 `funflix-web/scripts/setup.sh` 的做法）；没装 `gum` 就必须把
参数写全，脚本本身不负责装这个交互依赖。
