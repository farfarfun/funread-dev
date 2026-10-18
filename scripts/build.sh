#!/usr/bin/env bash
#  仓库根的发版入口：先把三个仓库的测试和 lint 跑一遍，全绿才交给 funbuild build。
#
#  funbuild build 是从本机直推 PyPI / npm 的，不经过 CI —— 两个 Python 仓库的
#  ci.yml 只能让问题在 push 之后几分钟可见，拦不住已经推上索引的版本。这里就是
#  那道前置关卡。它**不替代** funbuild（构建、发布、打 tag 仍全由它做），只是在
#  它前面加一道门。
#
#  注意 funbuild build 不能重跑：每执行一次都发一个新版本，没有 dry-run。所以
#  检查失败时必须在它之前退出，而不是让它跑完再报。
#
#    scripts/build.sh                 # 检查 + 发版
#    scripts/build.sh --skip-checks   # 跳过检查（明知故犯时用，比如只改了文档）
#    scripts/build.sh --check-only    # 只跑检查，不发版
#
#  其余参数原样透传给 funbuild build（例如 --version 1.1.200）。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

skip_checks=0
check_only=0
args=()
for arg in "$@"; do
  case "${arg}" in
    --skip-checks) skip_checks=1 ;;
    --check-only) check_only=1 ;;
    *) args+=("${arg}") ;;
  esac
done

step() { printf '\n== %s ==\n' "$*"; }

run_checks() {
  #  funread：ruff + 格式 + pytest（--all-extras 已在各自 .venv 里装好；
  #  --fail-on-skip 把「依赖没装所以 skip」当失败，和 CI 口径一致）
  step "funread: ruff"
  (cd apps/funread && uv run ruff check . && uv run ruff format --check .)
  step "funread: pytest"
  (cd apps/funread && uv run pytest -q --fail-on-skip)

  #  funread-api：本地联调装的是隔壁目录的 funread 源码（PYTHONPATH），和 CI
  #  装 PyPI 版那条路不同 —— 这里验的是「要发的核心库 + 要发的 API」这个组合。
  step "funread-api: ruff"
  (cd apps/funread-api && uv run ruff check . && uv run ruff format --check .)
  step "funread-api: pytest"
  (cd apps/funread-api && PYTHONPATH=src:../funread/src uv run pytest -q --fail-on-skip)

  step "funread-web: vue-tsc + 单元测试"
  (cd apps/funread-web && npx vue-tsc --noEmit && npm test --silent)
}

if [[ "${skip_checks}" -eq 0 ]]; then
  run_checks
  printf '\n全部检查通过。\n'
else
  printf '已跳过检查（--skip-checks）。\n' >&2
fi

if [[ "${check_only}" -eq 1 ]]; then
  exit 0
fi

exec funbuild build "${args[@]}"
