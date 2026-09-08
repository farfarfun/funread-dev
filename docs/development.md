# 本地开发指南

先读 [architecture.md](./architecture.md) 了解整体设计,这里只讲"怎么把环境跑起来"。

## 0. 一个必须先知道的坑:不要连到生产数据库

这台开发机的 `funsecret` 里已经配置了 `funread/cache/source/db_url`,指向一个**真实的生产 MySQL**。`resolve_database_url()` 的优先级是「环境变量 > funsecret > 本地 sqlite」,所以**任何本地调试、跑测试、起 API,都必须显式设置环境变量覆盖掉它**:

```bash
export FUNREAD_DATABASE_URL="sqlite:////tmp/funread-dev.db"
```

不设置这个变量、又能读到 funsecret 的机器上,`GenerateSourceTask(...).run_xxx(sync=True)` 之类的调用会**真的写生产库**。养成习惯:开一个新终端 / 写一个新脚本前,先确认这个变量有没有设。

## 1. Clone 与子模块

```bash
git clone --recurse-submodules https://github.com/farfarfun/funread-dev.git
# 或者已经 clone 过了、忘了带 submodule:
git submodule update --init --recursive
```

三个 submodule(`apps/funread`、`apps/funread-web`、`apps/funread-dat`)各自是独立 git 仓库,分别 `cd` 进去 `git status`/`git push`,不要在 `funread-dev` 根目录直接改子模块里的文件后指望根目录的 `git commit` 能提交内容 —— 根目录只记录子模块的 commit 指针(`git diff` 会显示 `Subproject commit xxx` 这种一行 diff)。改完子模块内容后,提交顺序应该是:**先在子模块仓库里 commit + push,再回到 `funread-dev` 根目录 `git add apps/xxx && git commit` 把指针提交上去**。

## 2. `funread`(后端库 + CLI 管线 + API)

### 2.1 Python 环境

这个项目用 `uv` 管理依赖,但**`uv sync` / `uv pip install -e .` 在当前目录布局下会直接报错**:

```
error: Distribution not found at: file:///.../funread-dev/apps/fundrive
```

原因见 [architecture.md 第 11 节](./architecture.md#11-已知技术债--限制):`pyproject.toml` 里 `[tool.uv.sources.fundrive/funsecret/funworker]` 写的相对路径期望这几个包是 `apps/` 下的同级目录,但实际上它们是 `~/workspace/github/farfarfun/fundrive` 等独立仓库,根本不在 `funread-dev` 里。这是历史遗留问题,不是这次改造引入的,**不要试图"顺手修一下" pyproject.toml 里的路径**(会牵扯到这几个包在其他项目里怎么被引用,超出这次改造范围)。

已验证可用的 workaround(前提:机器上已经有一个装好基础依赖的 `.venv`,这台机器是这样的情况):

```bash
cd apps/funread

# 只装本地 funread 包本身,--no-deps 跳过依赖解析,绕开 fundrive 路径问题
uv pip install --python .venv/bin/python --no-deps -e .

# 如果 .venv 里还没有 API 相关依赖,单独装:
uv pip install --python .venv/bin/python "fastapi>=0.110.0" "uvicorn[standard]>=0.27.0"
```

如果是**全新机器**、连基础依赖的 `.venv` 都没有,需要先把 `fundrive`、`funsecret`、`funworker` 这几个仓库 clone 出来并保证 uv 能解析到(比如临时改 `tool.uv.sources` 路径,或者干脆让 `uv` 走 PyPI 上已发布的版本 —— 检查一下这几个包是否已经发布到 PyPI/私有源),这个坑还没有一个"标准解法",遇到时按实际情况处理,处理完记得回来更新这一节文档。

### 2.2 跑一遍完整验证 checklist

这是当初实现这套数据层时实际跑通过的一遍验证步骤,新 agent 接手时可以照抄一遍,确认环境没坏:

```bash
cd apps/funread
export FUNREAD_DATABASE_URL="sqlite:////tmp/funread-smoketest.db"
rm -f /tmp/funread-smoketest.db*

# 1. 数据库地址解析:应该原样打印出上面设置的 sqlite 地址,而不是 funsecret 里的 MySQL
.venv/bin/python -c "
from funread.base.config import resolve_database_url
print(resolve_database_url())
"

# 2. 注册表能正常创建 store
.venv/bin/python -c "
from funread.legado.manage.download.sources import SourceStoreFactory, supported_source_types
print(supported_source_types())               # ['booksource', 'rsssource']
SourceStoreFactory.create(path='/tmp/funread-test', source_type='rsssource')
"

# 3. 建表 + 写一条假数据(不用跑真实采集管线,真实管线会打外网)
.venv/bin/python -c "
from funread.legado.manage.source.storage import init_source_db, upsert_source_list_record
init_source_db()
upsert_source_list_record(url='https://example.com/a.json', source_type='rss', source_count=3)
"

# 4. 起 API,curl 验证
.venv/bin/python -m uvicorn funread.api.app:app --host 127.0.0.1 --port 8123 &
sleep 2
curl -s localhost:8123/healthz                       # {"status":"ok"}
curl -s "localhost:8123/api/v1/sources?limit=10"      # 应该能看到刚才写的那条记录
kill %1

# 5. 备份脚本
.venv/bin/python -c "
from funread.legado.manage.download.core.db_backup import backup_sqlite_database
print(backup_sqlite_database(dest_dir='/tmp/funread-dat-test/hubs/db/bak'))
"
sqlite3 /tmp/funread-dat-test/hubs/db/bak/*.db ".tables"   # 应该看到三张表

# 清理
rm -rf /tmp/funread-smoketest.db* /tmp/funread-dat-test /tmp/funread-test
```

### 2.3 日常开发怎么起服务

```bash
export FUNREAD_DATABASE_URL="sqlite:////tmp/funread-dev.db"   # 别忘了这一步!
cd apps/funread
uv run funread-api
# 等价于:.venv/bin/python -m uvicorn funread.api.app:app --host 0.0.0.0 --port 8000
```

### 2.4 跑真实采集管线(会访问外网)

```bash
export FUNREAD_DATABASE_URL="sqlite:////tmp/funread-dev.db"
cd apps/funread
.venv/bin/python -c "
from funread.legado.manage.download import GenerateSourceTask
GenerateSourceTask().run_rss(download=True, sync=True)
"
```

`run_rss`/`run_book` 的开关(`load/download/check/merge/dump/sync/upload/publish`)对应第 3 节数据流图里的每一段,按需开关。`upload=True`/`publish=True` 会调用 `fundrive.GithubDrive` 往 `farfarfun/funread-cache` 传东西,本地调试一般不需要开。

### 2.5 跑测试

```bash
cd apps/funread
.venv/bin/python -m pytest tests/ -v
```

现有测试只覆盖 `storage.py`(见 `tests/test_source_download_storage.py`),这次新增的 `base/config.py`、`api/`、`core/db_backup.py` 还没有测试 —— 如果要补,参考现有测试里用 `tmp_path` 起临时 sqlite 文件的写法。

## 3. `funread-web`(前端)

```bash
cd apps/funread-web
pnpm install
```

第一次 `pnpm install` 大概率会报:

```
Error: ERR_PNPM_IGNORED_BUILDS
  × Ignored build scripts: esbuild@0.21.5
  help: Run "pnpm approve-builds" to pick which dependencies should be allowed to run scripts.
```

这是 pnpm 的安全机制(新版本默认不跑依赖的 postinstall 脚本),批准一下就行,批准结果已经写进 `pnpm-workspace.yaml`(`allowBuilds: esbuild: true`),提交过一次之后正常情况下不用再批:

```bash
pnpm approve-builds esbuild
pnpm install
```

起 dev server 前,确认 `funread` 的 API 已经在跑(见 2.3),然后:

```bash
# 如果 API 没跑在默认的 8000 端口,用 .env.local 覆盖(这个文件在 .gitignore 里,不会被提交)
echo "VITE_API_BASE_URL=http://127.0.0.1:8000" > .env.local

pnpm dev
```

浏览器打开控制台打印的地址(默认 `http://localhost:5173`,端口被占用会自动往后找),应该能看到一个渲染了 `source_list_records` 数据的表格。如果页面显示 "Failed to load sources: Failed to fetch",先检查 API 是不是真的在跑、`VITE_API_BASE_URL` 端口对不对,这不是 CORS 问题(`funread` API 已经把 CORS 全开了)。

## 4. `funread-dat`(数据/备份仓库)

这个仓库没有安装包,`scripts/` 下都是直接调 `funread` 库函数的小脚本,风格是顶层直接执行(不包 `if __name__ == "__main__"`),运行方式统一是 `python scripts/xxx.py`(这几个脚本 import 的是 `funread`,所以要在装好 `funread` 的 Python 环境里跑,比如 `apps/funread/.venv/bin/python`):

```bash
cd apps/funread-dat

# 把某个数据库地址写进 funsecret(通常只在换生产库地址时用一次,谨慎操作)
FUNREAD_DATABASE_URL='mysql+pymysql://user:password@host/database' \
  /path/to/funread/.venv/bin/python scripts/init.py

# 跑一遍完整采集(会写数据库、访问外网、可能上传网盘,谨慎运行)
/path/to/funread/.venv/bin/python scripts/upload.py

# 备份当前 sqlite 数据库文件到 hubs/db/bak/(本次新增)
FUNREAD_DATABASE_URL="sqlite:////tmp/funread-dev.db" \
  /path/to/funread/.venv/bin/python scripts/backup_db.py
```

备份/快照文件产出之后是**人工 `git add && commit && push`**,没有自动化。`hubs/book/pkl`、`hubs/book/source` 两个目录体积是 GB 级,已经在 `.gitignore` 里,提交前如果发现 `git status` 里冒出来这两个目录下的文件,说明 `.gitignore` 被动过或者路径变了,要停下来检查,不要直接 commit。

## 5. 常见坑速查表

| 现象 | 原因 | 处理 |
|---|---|---|
| `uv sync` / `uv pip install -e .` 报 `Distribution not found at .../apps/fundrive` | `pyproject.toml` 的 `tool.uv.sources` 相对路径在当前布局下无效 | 用 `uv pip install --python .venv/bin/python --no-deps -e .`,见 2.1 |
| `pnpm install` 报 `ERR_PNPM_IGNORED_BUILDS` | pnpm 默认不跑依赖的 postinstall | `pnpm approve-builds esbuild` |
| 前端页面 "Failed to fetch" | `VITE_API_BASE_URL` 没指对、或者 API 没起 | 检查 `.env.local`,确认 `curl` 那个地址能通 |
| 疑似"数据没落库"/`sync=True` 之后查不到数据 | 没设 `FUNREAD_DATABASE_URL`,connect 到了 funsecret 里的生产 MySQL(权限或网络问题导致静默失败,或者数据其实进了生产库) | 先 `resolve_database_url()` 打印一下实际连的是哪个库 |
| 怀疑不小心写了生产库 | 同上 | 立刻检查 `FUNREAD_DATABASE_URL` 有没有设置;如果确认误写了生产库,不要自己尝试回滚数据,找人确认影响范围 |
