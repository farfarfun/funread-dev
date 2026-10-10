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

## 阅读端：真账号（funauth）

| 项 | 值 |
| --- | --- |
| cookie | `session`（Starlette `SessionMiddleware` 的签名 cookie，宿主在 `app.py` 里装） |
| 会话内容 | **只有 `user_id`**，角色不进 cookie |
| 账号表 | `reader_user` + `reader_invite_code`，由 funauth 定义，口令是 bcrypt |
| 守卫 | `require_user` → `CurrentUser`，挂在 `/shelf` 与 `/rss`；`require_reader_admin` 要 `role == admin` |

账号、口令哈希、邀请码这三件事整体交给 funauth，本服务只提供两样：表的名字
（`reader_user` / `reader_invite_code`，通过 mixin 落在自己的 `AuthBase` 上）和部署
决定（cookie 名、过期、`https_only`、签名密钥从哪来）。funauth 明确不代劳后者。

**角色每个请求重查库**，不塞进 cookie：塞进去等于发一张撤不回的通行证，
`user disable` 或降级之后那张还没过期的 cookie 仍然好用。现在改一下库里的
`is_active` 立刻生效。

**签名密钥是落盘的**（`accounts.resolve_session_secret()`：env
`FUNREAD_SESSION_SECRET` > funsecret > 配置目录下 0600 的一个文件）。不能每次启动
随机生成 —— 阅读会话有效期一个月，而自托管的服务会因为升级、改配置、重启机器
重启好几次，每次都把所有人踢下线，对一个用手机看书的人来说就是故障。密钥写不进去
时退到临时密钥并打一条 WARN，说清楚「重启后要重新登录」而不是让人以为是 bug。

### 旧 scrypt 账号不用重设口令

M3d 那版自建的哈希是 `scrypt$n$r$p$salt$key`，bcrypt 验不了。`POST /auth/login` 在
发现这种哈希时（`accounts.is_legacy_hash`）自己验一次，成功就当场
`set_password` 换成 bcrypt。每个账号最多走这一次。不交给 `funauth.authenticate`
是因为它只认 bcrypt，会把老账号直接判成口令错。

**只有验证成功才短路**：验不过（或账号已停用）一律落回 `accounts.authenticate`
去抛 —— 在这儿自己抛一句措辞不同的 401 就等于告诉探测方「这个账号是升级前建的」。
这条路不会把老账号意外放行，因为 scrypt 串在 bcrypt 下必然验不过
（`funauth.security.verify_password` 对非法格式返回 `False` 而不是抛）。

## 注册：由库里的邀请码控制

`POST /auth/register` 两条路，分岔只看「现在有没有账号」：

- **零账号**（首次运行）：不要邀请码，第一个注册的人成 `admin`。这不多给任何权限
  —— 这台机器上本来就谁都能注册第一个账号。同时把 user 0 的存量数据认领过去。
- **已有账号**：必须带一张库里真实存在、未吊销、未过期、还有剩余名额的邀请码，
  由 funauth 的 `register_with_invite` 扣名额并建号，**角色硬编码成 `guest`**，
  不接受调用方指定 —— 否则邀请码外泄就等于交出后台。

所以「注册默认关闭」的实现变了：不再是 `FUNREAD_REGISTER_CODE` 未设置就 403，
而是**一张可用的码都没签发时注册实际上就是关着的**。`FUNREAD_REGISTER_OPEN`
因此默认**开**（和旧的 `FUNREAD_REGISTER_CODE` 相反）：默认关会让人签发了码却
注册不了，还查不出为什么。要彻底封死（比如公网暴露期间）设 `FUNREAD_REGISTER_OPEN=0`。

签发与吊销走 CLI：`funread-api accounts invite ...`。

## 登录失败不区分原因

funauth 的 `authenticate` 对「用户不存在」和「口令不对」抛同一个 `BadCredentials`，
路由翻成同一个 401 加同一句文案；用户不存在时也走一遍等开销的哈希计算，否则
「不存在」比「口令错」快得多，那本身就是一个可枚举用户名的计时信道。老账号那条
scrypt 分支的失败也转交给它，所以文案与计时补偿都是同一份，不泄露「这个账号是
升级前建的」。三条路径的响应体逐字节相同，有测试压着
（`test_a_legacy_account_is_not_distinguishable_by_its_failure_message`）。

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
