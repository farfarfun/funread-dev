-- funread 阅读端的数据表（账户 / 邀请码 / 源偏好 / 书架 / 进度 / 章节缓存）。
--
-- 本文件由 SQLAlchemy 模型生成（方言：SQLite），不要手改 —— 改模型再重新生成。
-- 生产用 MySQL，类型会按方言映射，列与约束一致。
-- 建表走 metadata.create_all() + 手写迁移，不引 Alembic。
-- 订阅源那两张表在 docs/development/rss-subscription/schema/001-schema.sql。
--
-- 两套 metadata：账号那两张表是 funauth 的（funread_api.accounts.AuthBase），
-- 其余是 funread 的（funread.legado.reader.storage.ReaderBase）。它们落在同一个
-- 库里，但归属不同的包 —— 账号表的形状由 funauth 的版本决定，不要在这边改。

-- 阅读端账号。**由 funauth 定义**，不是本仓库的模型。
-- 口令是 bcrypt（funauth 管哈希与校验），可为空 —— funauth 允许没有口令的账号。
-- 旧版自建的 scrypt 哈希（`scrypt$n$r$p$salt$key`）由 _migrate_legacy_user_table
-- 原样搬过来，在该账号下次登录成功时就地换成 bcrypt，见 accounts.is_legacy_hash。
-- role 是阅读端自己的角色（funauth 的 UserRole：admin / guest），第一个注册的账号
-- 是 admin，之后凭邀请码注册的都是 guest。和 B 端 /admin 的单口令完全分开 ——
-- 管理端不该和读者账号共用凭据。
CREATE TABLE reader_user (
	id INTEGER NOT NULL,
	username VARCHAR(64) NOT NULL,
	password_hash VARCHAR(128),
	role VARCHAR(16) NOT NULL,
	is_active BOOLEAN NOT NULL,
	created_at DATETIME NOT NULL,
	updated_at DATETIME NOT NULL,
	PRIMARY KEY (id),
	CONSTRAINT uq_reader_user_username UNIQUE (username)
);
CREATE INDEX ix_reader_user_created_at ON reader_user (created_at);

-- 注册邀请码。**由 funauth 定义。**
-- 注册默认关闭：没有任何一张可用的码时，/auth/register 一律 403 —— 能摸到局域网
-- 地址的东西不该能自己开账号。max_uses/used_count 是名额，扣减与回滚由 funauth
-- 的 register_with_invite 负责（名额扣了但用户名撞车时必须回滚，见 get_session）。
CREATE TABLE reader_invite_code (
	id INTEGER NOT NULL,
	code VARCHAR(32) NOT NULL,
	max_uses INTEGER NOT NULL,
	used_count INTEGER NOT NULL,
	expires_at DATETIME,
	is_active BOOLEAN NOT NULL,
	note TEXT,
	created_at DATETIME NOT NULL,
	updated_at DATETIME NOT NULL,
	PRIMARY KEY (id),
	CONSTRAINT uq_reader_invite_code_code UNIQUE (code)
);
CREATE INDEX ix_reader_invite_code_created_at ON reader_invite_code (created_at);

-- 一个源在阅读端的可用性与排序权重。source_type 分区（book / rss），
-- 两种源是两个独立的候选池。is_complete/needs_js/has_explore 是静态扫描结果，
-- fail_count/last_ok_at 是实跑积累 —— 后者才是可信的可用性信号。
CREATE TABLE reader_source_prefs (
	source_type VARCHAR(32) NOT NULL,
	url_id INTEGER NOT NULL,
	name VARCHAR(255) NOT NULL,
	enabled BOOLEAN NOT NULL,
	weight INTEGER NOT NULL,
	is_complete BOOLEAN NOT NULL,
	needs_js BOOLEAN NOT NULL,
	has_explore BOOLEAN NOT NULL,
	fail_count INTEGER NOT NULL,
	last_ok_at DATETIME,
	last_error VARCHAR(1024),
	created_at DATETIME NOT NULL,
	updated_at DATETIME NOT NULL,
	PRIMARY KEY (source_type, url_id)
);
CREATE INDEX ix_reader_source_prefs_enabled ON reader_source_prefs (enabled);
CREATE INDEX ix_reader_source_prefs_has_explore ON reader_source_prefs (has_explore);
CREATE INDEX ix_reader_source_prefs_weight ON reader_source_prefs (weight);

-- 书架。主键 (user_id, book_key)。user_id 必须进主键而不是只做索引列：
-- 两个人各自把同一本书加进书架是正常的，book_key 单独做主键会让第二个人加不进去。
-- book_key = md5(书名\n作者)，不跟源走 —— 换源时主键跟着源走会让书架冒出两条同名记录。
--
-- group 是分组名，空串 = 未分组（不用 NULL：空串能直接进 WHERE 等值比较和
-- GROUP BY，NULL 两边都要特例）。列名和 reader_rss_subscription.group 保持一致，
-- 代价是它在 SQLite 与 MySQL 里都是保留字 —— 手写的 ALTER TABLE 必须走方言的
-- identifier_preparer.quote，见 storage._migrate_added_columns。
--
-- chapter_count / last_checked_at / last_check_error 是「检查更新」的落点。
-- 未读数**不存**，由 chapter_count 和 reader_progress.chapter_index 算出来 ——
-- 存一份就要在每次翻页时跟着改，而它随时可以算。
-- 这四列都带 server_default：_migrate_user_scope 补 user_id 时走的是
-- INSERT ... SELECT 重建，Python 侧的 default= 不产生 DDL 的 DEFAULT 子句，
-- 存量库升级到这一版会在 NOT NULL 上失败。
CREATE TABLE reader_shelf (
	user_id INTEGER NOT NULL,
	book_key VARCHAR(32) NOT NULL,
	name VARCHAR(255) NOT NULL,
	author VARCHAR(255) NOT NULL,
	cover_url VARCHAR(1024) NOT NULL,
	intro TEXT NOT NULL,
	source_type VARCHAR(32) NOT NULL,
	url_id INTEGER NOT NULL,
	book_url VARCHAR(1024) NOT NULL,
	toc_url VARCHAR(1024) NOT NULL,
	last_chapter VARCHAR(512) NOT NULL,
	"group" VARCHAR(128) DEFAULT '' NOT NULL,
	chapter_count INTEGER DEFAULT 0 NOT NULL,
	last_checked_at DATETIME,
	last_check_error VARCHAR(512),
	created_at DATETIME NOT NULL,
	updated_at DATETIME NOT NULL,
	PRIMARY KEY (user_id, book_key)
);
CREATE INDEX ix_reader_shelf_group ON reader_shelf ("group");

-- 阅读进度。一人一本书一条。char_offset 是正文里的字符偏移而不是滚动像素 ——
-- 换了字号/设备之后像素值毫无意义，字符偏移还能换算回大致位置。
CREATE TABLE reader_progress (
	user_id INTEGER NOT NULL,
	book_key VARCHAR(32) NOT NULL,
	chapter_index INTEGER NOT NULL,
	chapter_url VARCHAR(1024) NOT NULL,
	chapter_name VARCHAR(512) NOT NULL,
	char_offset INTEGER NOT NULL,
	updated_at DATETIME NOT NULL,
	PRIMARY KEY (user_id, book_key)
);

-- 章节正文缓存，既是缓存也是离线下载的落点。
-- **故意不带 user_id**：这是正文缓存而不是个人数据，按人隔离只会让同一章存 N 份。
-- 代价是下架时不能无条件清缓存，见 remove_shelf_book。
CREATE TABLE reader_chapter_cache (
	book_key VARCHAR(32) NOT NULL,
	chapter_index INTEGER NOT NULL,
	chapter_url VARCHAR(1024) NOT NULL,
	title VARCHAR(512) NOT NULL,
	content TEXT NOT NULL,
	created_at DATETIME NOT NULL,
	PRIMARY KEY (book_key, chapter_index)
);
