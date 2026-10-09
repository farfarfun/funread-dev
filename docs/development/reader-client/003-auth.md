# 鉴权

两套凭据，两个 cookie，两组守卫。分开是故意的。

## 为什么分开

管理端那个口令能触发 `POST /sources` —— 服务端会去拉调用方给的任意 URL（SSRF
primitive）。读者登录看书不该顺带拿到这个能力；反过来，管理端的共享口令也不该
冒充某个具体读者（它背后没有 `user_id`，书架记给谁？）。

两个方向都有测试压着：`test_an_admin_cookie_is_not_a_reader_identity` 与
`test_a_reader_cookie_does_not_unlock_the_console`。

## 管理端：预共享口令

| 项 | 值 |
| --- | --- |
| cookie | `funread_session` |
| 口令来源 | `FUNREAD_API_PASSWORD` > funsecret `funread/api/auth/password` > 无 |
| token 格式 | `<expires_at>.<hmac_sha256(password, "v1.<expires_at>")>` |
| 守卫 | `require_session`，挂在 `/sources` |

签名密钥就是口令本身，所以改口令会让所有未过期的管理 session 失效。这是唯一的
吊销手段，也是自托管真正需要的那个。

没配口令 = 完全开放 + 启动时一条 WARN。这保住了「新克隆直接能跑」，但也意味着
一旦把 `FUNREAD_API_HOST` 改成 `0.0.0.0`，就必须同时配口令。

## 阅读端：真账号

| 项 | 值 |
| --- | --- |
| cookie | `funread_user` |
| 账号表 | `reader_user`，口令存 `hashlib.scrypt` 哈希 |
| token 格式 | `r1.<user_id>.<expires_at>.<hmac_sha256(password_hash, "r1.<user_id>.<expires_at>")>` |
| 守卫 | `require_user` → `CurrentUser`，挂在 `/shelf` 与 `/rss` |

**签名密钥是用户的 `password_hash`**，所以改口令会让该用户所有未过期的 session
立刻失效。验证时要查一次库拿哈希 —— 一次主键查询，换来自动吊销，划算。

口令哈希用 stdlib 的 `hashlib.scrypt`（`n=2**14, r=8, p=1`），不引 passlib/bcrypt：
funread 的依赖面要维持现状，而 scrypt 本身就是为抗硬件爆破设计的。参数编进哈希串
（`scrypt$n$r$p$salt$key`），以后调大不会让已有口令失效。

`verify_password` **永不抛**：哈希串格式坏了就是验证失败，不是 500。

## 注册：默认关闭

`POST /auth/register` 在 `FUNREAD_REGISTER_CODE` 未设置时直接 403。默认关闭是唯一
安全的默认值 —— 任何能连到局域网地址的人否则都能开账号、消耗服务端的抓取预算。

邀请码用 `hmac.compare_digest` 比，不是 `==`（普通比较会按时间泄露邀请码）。

## 登录失败不区分原因

`storage.authenticate` 在「用户不存在」和「口令不对」两种情况下都返回 `None`，
路由翻成同一个 401 加同一句文案。而且用户不存在时也会走一遍等开销的哈希计算 ——
否则「不存在」比「口令错」快得多，那本身就是一个可枚举用户名的计时信道。

## 隐式本地身份

`user_id = 0` 是「还没有任何账号」时的身份。它成立需要**两个**条件同时满足：

1. `count_users() == 0`；
2. 管理端守卫已满足（没配口令时即为满足）。

第二个条件很关键。少了它，一个原本靠 `FUNREAD_API_PASSWORD` 锁住一切的部署，升级
到账号体系之后书架会对局域网敞开。

第一个账号注册时会把 user 0 的存量数据**认领**过去（`claim_local_data`）。之后
user 0 不再可达 —— 否则第一个人的书架就对任何人可读。

## 公开阅读端开关

`FUNREAD_READER_PUBLIC=1` 让 `/reader/*` 的安全方法（GET/HEAD/OPTIONS）免登录。
这些端点是无状态的（搜索、解析、抓取），没有用户维度。

**它不放开任何带状态的东西**：`/shelf`、`/rss`、`POST /reader/scan`、
`POST /sources` 都不受影响。这条也有测试。

## 为什么 cookie 是 secure=False

服务通常通过 `http://192.168.x.x:8811` 访问，而 `secure` cookie 在纯 http 下根本
不会被浏览器送回来 —— 加上它等于让登录直接失效。代价是这套鉴权不能暴露到公网，
见 [`产品范围与约束`](../../product/reader-client/003-scope-and-constraints.md)。

两个 cookie 都是 `httponly`（只有服务端读，给 JS 访问只会扩大 XSS 的后果）
加 `samesite=lax`。
