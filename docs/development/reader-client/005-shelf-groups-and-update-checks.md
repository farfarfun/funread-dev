# 书架分组与批量检查更新

## 分组是 `reader_shelf` 上的一个字符串

没有分组表。`reader_shelf.group` 存分组名，空串 = 未分组。

所以三个「分组操作」全都是对书的 UPDATE，没有一个要管分组自己的生命周期：

| 操作 | 实际做的事 |
| --- | --- |
| 建组 | 把几本书的 `group` 设成一个新名字 |
| 移动 | 同上 |
| 解散 | 把该组的书 `group` 改成空串（`rename(old, "")`） |
| 改名 | `UPDATE ... SET "group" = :new WHERE "group" = :old` |

这个形状的好处是不会攒下「空分组」——那种只存在于分组表里、一本书都没有的记录，
只能靠界面定期打扫。代价是改名要扫一遍该组的书，但书架是几十到几百本的量级。

分组名就是标识，所以没有「重命名成一个已存在的名字」这种冲突：那等于合并两个组，
也正是用户那么做时想要的结果。

### 空串与「没传」必须分开

这件事在三个地方各出现一次，每处的解法不同：

- **HTTP**：`GET /shelf?group=` 是「只看未分组的书」，不传 `group` 是「整个书架」。
  所以参数类型是 `str | None = Query(default=None)`，不是 `str = ""`。
- **web 的 `query()` 辅助函数**会丢掉空串（对 `q`、`title` 这些是对的），于是
  `api.shelf(group)` 这一个 URL 是手拼的，不走 `query()`。
- **localStorage** 里存的当前分组用 JSON 存，`""` 和「从没存过」才区分得开。

### `POST /shelf` 不动分组

`ShelfBookIn.group` 的默认值是 `None` 而不是 `""`。这个端点是幂等的 —— 从搜索结果
里再点一次「加入书架」很常见，而那时请求里不会带分组。默认成空串就会把书从用户
分好的组里踢回未分组。

### `group` 是保留字

SQLite 和 MySQL 都把它当保留字，而且引号不一样。SQLAlchemy 的表达式层自己会引，
但 `storage._migrate_added_columns` 里手写的 `ALTER TABLE` 不会 —— 那里走
`engine.dialect.identifier_preparer.quote`。

列名仍然叫 `group`，为了和 `reader_rss_subscription.group` 一致。

## 未读数算出来，不存

```
unread = max(0, chapter_count - (progress.chapter_index + 1))
```

`chapter_count` 是上次检查更新时数到的章节总数。存一份 `unread` 就要在每次翻页时
跟着改对，而它随时可以从两个已有的值算出来。

`chapter_count == 0` 的含义是「**还没查过**」，不是「没有章节」。界面据此不画角标，
而不是画一个 0。

## 检查更新是后台任务

一本书要两次抓取（详情拿当前的 `toc_url`，再拉目录数章节数），几十本就是几分钟，
撑不过任何合理的请求超时。所以：

```
POST /shelf/check-updates   → 202 {task_id, queued}
GET  /shelf/check-updates/{task_id} → {state, total, done, failed}
```

前端按 1.5 秒轮询。默认每本之间 `interval=1` 秒：书架里的书往往来自同一个站点，
不限速就是对人家连着打几十个请求。

### 一个账号一轮

第二次请求返回 409，并带上正在跑的那个 `task_id`，让界面直接接上去轮询而不是另起
一轮重复抓取。这靠 `TaskTracker.active_for(scope, user_id)` 实现，检查更新这种
「每人一个」的任务传 `scope=""`，于是「一人同时只能有一个」和下载的「一本书同时
只能下一次」落在同一个判断上。

下载和检查更新用**两个** `TaskTracker` 实例而不是一个共享的：共享的话
`active_for` 会在问「有没有在检查更新」时看见一个下载任务，而且保留上限会让一个
忙碌的下载队列把检查记录挤掉。

### 失败记在书上，不只记在任务上

`last_check_error` 存在 `reader_shelf` 上。任务记录十分钟后就回收了，而「这本书
上次检查失败了」是用户下次打开书架时还该看见的信息 —— 界面在那本书上标一个感叹号。
成功一次就清掉。

没记住来源的书（`url_id` 为空）直接记一条 `这本书没有记住来源，先换一次源`，不去
猜一个源 —— 猜错了会把进度搬到另一本同名书上。

### `updated_at` 不能被碰

`ReaderShelfBook.updated_at` 带 `onupdate=utcnow`，而书架默认按它排序。检查更新和
移动分组都要写这张表，如果让 `onupdate` 生效，跑一轮检查就会把整个书架的顺序按
「检查完成的先后」重排一遍 —— 用户没动过任何一本书，书架却整个洗牌了。

解法是显式把该列放进 SET 子句（显式赋值会压掉 `onupdate`），赋它自己：

```python
_PRESERVE_UPDATED_AT = ReaderShelfBook.updated_at
```

## 存量库升级

`reader_shelf` 新增的四列都带 `server_default`。

这不是风格问题：补 `user_id` 那次迁移（`_migrate_user_scope`）走的是建新表 +
`INSERT ... SELECT` 的重建流程，而 SQLAlchemy 的 `default=` 只在 Python 侧生效、
**不产生 DDL 的 DEFAULT 子句**。少了 `server_default`，存量库升级到这一版会在
`NOT NULL` 上失败。
