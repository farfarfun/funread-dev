-- funread 订阅源的数据表。
--
-- 本文件由 SQLAlchemy 模型生成（方言：SQLite），不要手改 —— 改模型再重新生成。
-- 这两张表建表时就带 user_id，不需要迁移（书架与进度那两张是 M2 时建的，
-- 补 user_id 走了 _migrate_user_scope 的重建流程）。

-- 一条订阅。两种来源共用一张表，由 kind 区分：
--   kind='legado' → 归档里的 Legado RSS 源，url_id 指过去
--   kind='feed'   → 用户自己贴的标准 feed 地址，feed_url
-- sub_id = md5(kind\n来源标识)，不是自增 —— 重复订阅同一个源要幂等。
-- 两个人订同一个源得到同一个 sub_id，所以主键是 (user_id, sub_id)。
CREATE TABLE reader_rss_subscription (
	user_id INTEGER NOT NULL, 
	sub_id VARCHAR(32) NOT NULL, 
	kind VARCHAR(16) NOT NULL, 
	url_id INTEGER NOT NULL, 
	feed_url VARCHAR(1024) NOT NULL, 
	title VARCHAR(255) NOT NULL, 
	icon VARCHAR(1024) NOT NULL, 
	"group" VARCHAR(128) NOT NULL, 
	last_fetched_at DATETIME, 
	last_error VARCHAR(1024), 
	created_at DATETIME NOT NULL, 
	updated_at DATETIME NOT NULL, 
	PRIMARY KEY (user_id, sub_id)
);

-- 文章的已读 / 收藏状态。**只存状态不存正文** ——
-- 订阅文章时效性强、量大（一个活跃订阅一周几千篇），缓存正文收益低占用高。
-- 标题和链接存一份是为了收藏列表能脱离原始列表单独渲染。
-- article_key = md5(link)：feed 的 guid 五花八门，链接是唯一普遍可用的稳定标识。
CREATE TABLE reader_rss_article_state (
	user_id INTEGER NOT NULL, 
	sub_id VARCHAR(32) NOT NULL, 
	article_key VARCHAR(32) NOT NULL, 
	read BOOLEAN NOT NULL, 
	favorited BOOLEAN NOT NULL, 
	title VARCHAR(512) NOT NULL, 
	link VARCHAR(1024) NOT NULL, 
	pub_date VARCHAR(64) NOT NULL, 
	image VARCHAR(1024) NOT NULL, 
	updated_at DATETIME NOT NULL, 
	PRIMARY KEY (user_id, sub_id, article_key)
);
CREATE INDEX ix_reader_rss_article_state_favorited ON reader_rss_article_state (favorited);
CREATE INDEX ix_reader_rss_article_state_read ON reader_rss_article_state (read);
