# 阅读服务层与鉴权用例

## 阅读服务层（151 个，`tests/reader/`）

| 文件 | 组 | 重点 |
| --- | --- | --- |
| `test_registry.py` | 候选源池 | 扫描统计、选源排序、表里 enabled 但文件没了的情况 |
| `test_reader_service.py` | 门面 | 并发聚合搜索、按 `book_key` 合并、单源失败记账 |
| `test_reader_storage.py` | 四张表 | 书架/进度/缓存的读写与连带删除 |
| `test_user_accounts.py` | 账号（40 个） | 见下 |
| `test_rss_storage.py` | 订阅两张表（28 个） | 幂等订阅、按人隔离、已读/收藏、退订连带清理 |
| `test_rss_service.py` | 订阅门面（30 个） | 两条腿分派、订阅前验证、抓取失败记账 |

### 账号用例的四组

1. **口令哈希**：往返、加盐（两次同口令不同哈希）、参数编码、**哈希串坏了不抛**
   （五种畸形输入都只是验证失败，不是 500）。
2. **建账号**：用户名规则、口令长度、重复用户名、**明文不落库**（扫一遍整行确认
   没有口令原文）。
3. **登录**：正确、口令错、用户不存在、已禁用 —— 后三者外部不可区分。
4. **认领与隔离**：首个账号认领 user 0 的数据、第二个账号什么都不认领、
   `payload` 不能夹带 `user_id`、两个人能加同一本书、知道 `book_key` 也看不到
   别人的书。

### 迁移用例

`test_migration_moves_existing_rows_to_the_local_user` 照 M2 时的形状（无 `user_id`、
主键是 `book_key`）手建两张表并插数据，然后清掉 `_INITIALIZED_DATABASES` 模拟进程
重启、跑 `init_reader_db`，断言数据搬到了 user 0 且**旧表已删**（不留两份真相）。

`test_migration_then_first_registration_hands_the_data_over` 把迁移和认领串起来测 ——
那才是完整的升级路径。

## 鉴权边界（`funread-api/tests/test_auth.py`）

最值得留的是这四个，因为它们测的是**不该发生的事**：

| 用例 | 测什么 |
| --- | --- |
| `test_the_admin_password_still_locks_the_shelf_while_no_account_exists` | 一个原本靠 `FUNREAD_API_PASSWORD` 锁住一切的部署，升级到账号体系后不能悄悄失去保护 |
| `test_once_an_account_exists_the_local_fallback_is_gone` | 否则第一个人的书架会对局域网敞开 |
| `test_an_admin_cookie_is_not_a_reader_identity` | 解锁控制台不该顺带拿到某人的书架 |
| `test_a_reader_cookie_does_not_unlock_the_console` | 读书不是管理 —— `POST /sources` 是 SSRF primitive |

加上 `test_reader_public_does_not_open_writes` / `..._the_ssrf_endpoint`：
`FUNREAD_READER_PUBLIC` 只放开无状态的只读端点。

## 跨用户隔离（API 层）

`test_shelves_do_not_leak_between_accounts` 用两个 `TestClient` 分别注册两个账号，
断言 bob 看不到 alice 的书，而且**知道 `book_key` 也不行** —— 对进度、删除、
缓存查询三个端点各试一次，全是 404（不是 403：说「禁止」等于确认它存在）。
