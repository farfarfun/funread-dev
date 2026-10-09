#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

readonly -a SERVICE_ACTIONS=(start stop restart run status)
readonly -a RELEASE_ACTIONS=(install-dev install-prod upgrade rollback)
readonly -a ACTIONS=("${SERVICE_ACTIONS[@]}" "${RELEASE_ACTIONS[@]}")
readonly -a TARGETS=(api web core dat all)

# all 的含义按 action 分组而定：service action 只覆盖 service app，
# release action 覆盖 service + package app。
readonly -a ALL_SERVICE_APPS=(api web)
readonly -a ALL_RELEASE_APPS=(api web core dat)

usage() {
  printf 'Usage: %s <start|stop|restart|run|status> <api|web|all>\n' "${0##*/}" >&2
  printf '       %s install-dev <api|web|core|dat|all>\n' "${0##*/}" >&2
  printf '       %s <install-prod|upgrade> <api|web|core|dat|all> [version]\n' "${0##*/}" >&2
  printf '       %s rollback <api|web|core|dat|all> <version>\n' "${0##*/}" >&2
  printf '\n' >&2
  printf 'service actions (start/stop/restart/run/status) 只适用于 service app：api web\n' >&2
  printf 'release actions (install-dev/install-prod/upgrade/rollback) 适用于 service + package app：api web core dat\n' >&2
  printf 'build/publish 不是本脚本的 action —— 由仓库根的 `funbuild build`（scripts/build.sh）统一 fan out。\n' >&2
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 2
}

contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "${item}" == "${needle}" ]] && return 0
  done
  return 1
}

choose() {
  command -v gum >/dev/null 2>&1 ||
    die "缺少参数且没有安装 gum，请把参数写全后重试"
  gum choose "$@"
}

# Service app：有东西把它当长驻进程启动并与之通信。只有这些接受 service action。
# 分类是在这里显式登记的，不从仓库名后缀推断。
resolve_service_app() {
  case "$1" in
    api) printf '%s\n' "apps/funread-api" ;;
    web) printf '%s\n' "apps/funread-web" ;;
    *) return 1 ;;
  esac
}

# Package app：只会被安装成依赖，没有任何东西把它当进程启动。
# core = funread 核心库；dat = funread-dat 数据仓库（只支持 install-dev，
# 其余 release action 由它自己的 scripts/setup.sh 明确报错，见该脚本注释）。
resolve_package_app() {
  case "$1" in
    core) printf '%s\n' "apps/funread" ;;
    dat) printf '%s\n' "apps/funread-dat" ;;
    *) return 1 ;;
  esac
}

# Release action 对 service app 与 package app 一视同仁。
# nested workspace app 两者都不解析 —— 本仓库目前没有这类 app。
resolve_release_app() {
  resolve_service_app "$1" 2>/dev/null || resolve_package_app "$1" 2>/dev/null
}

is_service_action() {
  contains "$1" "${SERVICE_ACTIONS[@]}"
}

# 多 app 时按 ALL_* 数组的声明顺序依次处理；set -e 下第一个失败即中止，
# 不继续处理后面的 app。
dispatch_app_action() {
  local action="$1" target="$2" version="${3:-}" app path
  local -a apps
  if [[ "${target}" == "all" ]]; then
    if is_service_action "${action}"; then
      apps=("${ALL_SERVICE_APPS[@]}")
    else
      apps=("${ALL_RELEASE_APPS[@]}")
    fi
  else
    apps=("${target}")
  fi
  for app in "${apps[@]}"; do
    if is_service_action "${action}"; then
      path="$(resolve_service_app "${app}")" ||
        die "${action} 只适用于 service app，不适用于：${app}"
    else
      path="$(resolve_release_app "${app}")" || die "${action} 不适用于：${app}"
    fi
    printf '== %s: %s ==\n' "${app}" "${action}"
    (cd "${path}" && ./scripts/setup.sh "${action}" ${version:+"${version}"})
  done
}

main() {
  local action="${1:-}"
  local target="${2:-}"
  local version="${3:-}"

  [[ -n "${action}" ]] || action="$(choose "${ACTIONS[@]}")"
  contains "${action}" "${ACTIONS[@]}" || {
    usage
    die "unknown action: ${action}"
  }

  [[ -n "${target}" ]] || target="$(choose "${TARGETS[@]}")"

  case "${action}" in
    rollback)
      [[ -n "${version}" ]] ||
        die "rollback 必须显式给出版本号：${0##*/} rollback <api|web|core|dat|all> <version>"
      contains "${target}" "${TARGETS[@]}" || {
        usage
        die "unknown target: ${target}"
      }
      dispatch_app_action "${action}" "${target}" "${version}"
      ;;
    *)
      contains "${target}" "${TARGETS[@]}" || {
        usage
        die "unknown target: ${target}"
      }
      dispatch_app_action "${action}" "${target}" "${version}"
      ;;
  esac
}

main "$@"
