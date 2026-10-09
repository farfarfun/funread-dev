# 采集源管理 API(`funread-api/`)


独立仓库,依赖 `funread` 核心库(采集源模型/存储层留在 `funread` 里):

```
funread-api/src/funread_api/
├── app.py          # create_app():FastAPI 实例 + /healthz;lifespan 里建表(采集表 + 阅读表)
├── security.py     # 预共享口令 + hmac 签名 session cookie,require_session/require_reader
└── v1/
    ├── __init__.py # 聚合 router,顺便决定每个子 router 挂哪个鉴权依赖
    ├── auth.py     # /auth/login、/auth/me、/auth/logout
    ├── deps.py     # 进程内共享的 ReaderService + 引擎异常 → HTTP 状态码的映射
    ├── sources.py  # 采集源:列表/登记/启停/删除/采集/重置刷新时间
    ├── reader.py   # 阅读端:/reader/search、/book、/toc、/content、/sources、/scan
    └── shelf.py    # 书架、阅读进度、离线缓存
```

`deps.py` 的异常映射是前端行为的依据:**422 = 这个源永远跑不了**(phase 1 没有 JS 引擎,该提示换源),**502 = 这次源站抽风**(该提示重试),404 = 源或书不存在。

`POST /reader/scan` 要在第一次搜索之前跑一次:它扫本地归档、把"字段齐不齐 / 要不要 JS"的静态判定写进 `reader_source_prefs`,在那之前候选池是空的,搜索只会返回空结果。

对比 funflix `api/app.py` 的取舍:

- **最简鉴权(预共享口令 + 签名 cookie)**:`security.py` 读 env `FUNREAD_API_PASSWORD`(其次 funsecret `funread/api/auth/password`);`POST /api/v1/auth/login` 下发 stdlib hmac 签名的 `funread_session` cookie(HttpOnly/SameSite=Lax,有效期 30 天)。**未配置口令 = 全接口开放**,只在启动时打一条 WARN —— 这是为了不打断原来的本机单用户用法,不是安全默认值。`/sources`(含服务端拉任意 URL 的登记接口)和 `/shelf` 始终要 session;`FUNREAD_READER_PUBLIC=1` 只放开阅读端的只读 GET。
- **监听地址**:`run()` 的默认值是 `FUNREAD_API_HOST`,缺省 `127.0.0.1`。*之前这里写着"默认监听 127.0.0.1",而代码里硬编码的是 `0.0.0.0`* —— 现在代码和文档对齐了。手机访问需要改成 `FUNREAD_API_HOST=0.0.0.0`,那时**必须**同时配 `FUNREAD_API_PASSWORD`。
- **没有异步**:见第 5 节,和现有 storage.py 保持同步一致。
- **没有 CORS**:浏览器只访问 `funread-web` 的同源 `/api`;前端服务再把请求转发到默认监听 `127.0.0.1:18811` 的后端,和 funflix-web 的调用方式一致。
- `lifespan` 只做了 `init_source_db()`(建表 + 连接探测),没有像 funflix 那样起后台 worker —— 这次范围里压根没有 worker。

`funread-api` 自己的 `pyproject.toml` 依赖 `funread`(开发态通过 `[tool.uv.sources]` 指到 `../funread`)、`fastapi`、`uvicorn[standard]`,并声明 `[project.scripts] funread-api = "funread_api.app:run"` 入口。`funread` 自身的 `web` extra(`nicegui`)是历史死代码,没有动它,也没有复用它的名字。
