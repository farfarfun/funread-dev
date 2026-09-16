#!/bin/sh
# funread-dev 跨仓库统一入口：scripts/setup.sh <action> <target>
#
# 参数缺失时用 gum 交互补齐（参考 funflix-web/scripts/setup.sh 的做法）；
# 没装 gum 就必须把参数写全，脚本本身不负责装交互依赖。
set -e

cd "$(dirname "$0")/.."

# CLI-bearing apps only: short alias -> submodule path. Only these implement
# the Entrypoint Contract and their own scripts/setup.sh.
resolve_cli_app() {
  case "$1" in
    api) echo "apps/funread-api" ;;
    web) echo "apps/funread-web" ;;
    *) echo "" ;;
  esac
}
cli_apps="api web"

# 每个子模块 build 时的候选别名。funread-dat 不是 Python 包（uv package = false），
# 只需要 push 代码，故意不出现在这里 —— 加新的可打包 app 时同步补上。
buildable_apps="api web funread"

usage() {
  cat >&2 <<'EOF'
usage: scripts/setup.sh <action> <target>

action: start|stop|restart|run|status|install|publish|build
target: api|web|all（build 额外支持 apps/<name> 这种字面路径）

不带参数运行会用 gum 交互选择缺失的部分；没装 gum 时必须把参数写全。

说明：
  start/stop/restart/run/status/install/publish 只对 CLI-bearing 的 api/web 生效，
  转发到各自的 scripts/setup.sh <action>。
  build 覆盖 funread、funread-api、funread-web（不含 funread-dat —— 它只是脚本仓库，
  不打包，改完直接在自己仓库里 commit + push 即可），最后统一执行一次 funbuild push。
EOF
  exit 1
}

choose() {
  command -v gum >/dev/null 2>&1 || {
    echo "缺少参数，且未安装 gum；请用完整参数调用，见 scripts/setup.sh --help" >&2
    exit 1
  }
  gum choose "$@"
}

case "${1:-}" in
  -h|--help|help) usage ;;
esac

action="$1"
[ -n "$action" ] || action="$(choose start stop restart run status install publish build)"

case "$action" in
  start|stop|restart|run|status|install|publish)
    target="$2"
    [ -n "$target" ] || target="$(choose all api web)"
    if [ "$target" = "all" ]; then
      apps="$cli_apps"
    else
      apps="$target"
    fi
    for app in $apps; do
      path="$(resolve_cli_app "$app")"
      [ -n "$path" ] || { echo "not a CLI-bearing app: $app" >&2; exit 1; }
      echo "== $app: $action =="
      (cd "$path" && ./scripts/setup.sh "$action")
    done
    ;;
  build)
    target="$2"
    [ -n "$target" ] || target="$(choose all $buildable_apps)"
    if [ "$target" = "all" ]; then
      apps="$buildable_apps"
      paths=""
      for app in $apps; do
        path="$(resolve_cli_app "$app")"
        [ -n "$path" ] || path="apps/$app"
        paths="$paths $path"
      done
    else
      path="$(resolve_cli_app "$target")"
      [ -n "$path" ] || path="apps/$target"
      paths="$path"
    fi
    for path in $paths; do
      echo "== $path: build =="
      git -C "$path" switch master
      (cd "$path" && funbuild build)
    done
    funbuild push
    ;;
  *)
    usage
    ;;
esac
