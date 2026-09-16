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

## 构建

安装并配置好 `funbuild` 后执行：

```bash
bash scripts/build.sh
```

该脚本会将每个子项目切换到 `master` 分支、依次执行 `funbuild build`，
最后在本仓库执行一次 `funbuild push`，把更新后的子模块指针作为一次提交推送。
