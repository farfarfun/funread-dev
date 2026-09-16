#!/bin/sh
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

# Every submodule under apps/, CLI-bearing or not (core library + funread-dat).
all_app_paths() {
  git submodule status | awk '{print $2}'
}

usage() {
  echo "usage: scripts/setup.sh <start|stop|restart|run|status|install|publish> <api|web|all>" >&2
  echo "       scripts/setup.sh build <api|web|all|apps/<name>>" >&2
  exit 1
}

action="$1"
target="$2"
[ -n "$action" ] && [ -n "$target" ] || usage

case "$action" in
  start|stop|restart|run|status|install|publish)
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
    if [ "$target" = "all" ]; then
      paths="$(all_app_paths)"
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
