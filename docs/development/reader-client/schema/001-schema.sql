-- funread 阅读端的数据表（账户 / 源偏好 / 书架 / 进度 / 章节缓存）。
--
-- 本文件由 SQLAlchemy 模型生成（方言：SQLite），不要手改 —— 改模型再重新生成。
-- 生产用 MySQL，类型会按方言映射，列与约束一致。
-- 建表走 ReaderBase.metadata.create_all() + 手写迁移，不引 Alembic。
-- 订阅源那两张表在 docs/development/rss-subscription/schema/001-schema.sql。

-- 阅读端账号。口令只存 scrypt 哈希（`scrypt$n$r$p$salt$key`），明文不落库。
-- 和 B 端 /admin 的单口令完全分开 —— 管理端不该和读者账号共用凭据。
CREATE TABLE reader_user (
	user_id INTEGER NOT NULL, 
	username VARCHAR(32) NOT NULL, 
	password_hash VARCHAR(255) NOT NULL, 
	disabled BOOLEAN NOT NULL, 
	created_at DATETIME NOT NULL, 
	updated_at DATETIME NOT NULL, 
	PRIMARY KEY (user_id)
);
CREATE UNIQUE INDEX ix_reader_user_username ON reader_user (username);

-- 一个源在阅读端的可用性与排序权重。source_type 分区（book / rss），
-- 两种源是两个独立的候选池。is_complete/needs_js 是静态扫描结果，
-- fail_count/last_ok_at 是实跑积累 —— 后者才是可信的可用性信号。
CREATE TABLE reader_source_prefs (
	source_type VARCHAR(32) NOT NULL, 
	url_id INTEGER NOT NULL, 
	name VARCHAR(255) NOT NULL, 
	enabled BOOLEAN NOT NULL, 
	weight INTEGER NOT NULL, 
	is_complete BOOLEAN NOT NULL, 
	needs_js BOOLEAN NOT NULL, 
	fail_count INTEGER NOT NULL, 
	last_ok_at DATETIME, 
	last_error VARCHAR(1024), 
	created_at DATETIME NOT NULL, 
	updated_at DATETIME NOT NULL, 
	PRIMARY KEY (source_type, url_id)
);
CREATE INDEX ix_reader_source_prefs_enabled ON reader_source_prefs (enabled);
CREATE INDEX ix_reader_source_prefs_weight ON reader_source_prefs (weight);

-- 书架。主键 (user_id, book_key)。user_id 必须进主键而不是只做索引列：
-- 两个人各自把同一本书加进书架是正常的，book_key 单独做主键会让第二个人加不进去。
-- book_key = md5(书名\n作者)，不跟源走 —— 换源时主键跟着源走会让书架冒出两条同名记录。
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
	created_at DATETIME NOT NULL, 
	updated_at DATETIME NOT NULL, 
	PRIMARY KEY (user_id, book_key)
);

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
