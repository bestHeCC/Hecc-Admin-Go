-- Hecc-Admin-Go PostgreSQL 初始化脚本
--
-- 必须使用 psql 执行（脚本使用了 \gexec / \connect 元命令）：
--   psql -h 127.0.0.1 -U postgres -d postgres -f scripts/init.sql
--
-- 脚本可重复执行：
--   - 数据库存在时跳过创建；
--   - 表使用 IF NOT EXISTS；
--   - 种子数据使用 ON CONFLICT DO NOTHING。
--
-- 项目不使用 Go 迁移工具，表结构以本文件为准。修改模型时请同步修改这里，
-- 并保持 GORM 模型（server/entity/model）的列名与本文件一致。

\set ON_ERROR_STOP on

-- ---------------------------------------------------------------------------
-- 1. 创建数据库（不存在时）
-- ---------------------------------------------------------------------------
SELECT 'CREATE DATABASE "hecc-admin" WITH ENCODING ''UTF8'' TEMPLATE template0'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'hecc-admin')\gexec

\connect "hecc-admin"

BEGIN;

-- ---------------------------------------------------------------------------
-- 2. 部门
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_dept (
    id          BIGSERIAL PRIMARY KEY,
    parent_id   BIGINT       NOT NULL DEFAULT 0,
    ancestors   VARCHAR(500) NOT NULL DEFAULT '0', -- 形如 0,1,3
    name        VARCHAR(64)  NOT NULL,
    leader      VARCHAR(64)  NOT NULL DEFAULT '',
    phone       VARCHAR(32)  NOT NULL DEFAULT '',
    email       VARCHAR(128) NOT NULL DEFAULT '',
    sort        INT          NOT NULL DEFAULT 0,
    status      SMALLINT     NOT NULL DEFAULT 1, -- 0 禁用 / 1 启用
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    deleted_at  TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_sys_dept_parent_id ON sys_dept (parent_id);
CREATE INDEX IF NOT EXISTS idx_sys_dept_ancestors ON sys_dept (ancestors);

-- ---------------------------------------------------------------------------
-- 3. 岗位
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_post (
    id          BIGSERIAL PRIMARY KEY,
    code        VARCHAR(64)  NOT NULL,
    name        VARCHAR(64)  NOT NULL,
    sort        INT          NOT NULL DEFAULT 0,
    status      SMALLINT     NOT NULL DEFAULT 1,
    remark      VARCHAR(500) NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    deleted_at  TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_sys_post_code
    ON sys_post (code) WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------------
-- 4. 用户
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_user (
    id                   BIGSERIAL PRIMARY KEY,
    username             VARCHAR(64)  NOT NULL,
    password_hash        VARCHAR(255) NOT NULL,
    nickname             VARCHAR(64)  NOT NULL DEFAULT '',
    email                VARCHAR(128) NOT NULL DEFAULT '',
    phone                VARCHAR(32)  NOT NULL DEFAULT '',
    avatar               VARCHAR(255) NOT NULL DEFAULT '',
    dept_id              BIGINT       NOT NULL DEFAULT 0,
    status               SMALLINT     NOT NULL DEFAULT 1, -- 0 禁用 / 1 启用
    is_super             BOOLEAN      NOT NULL DEFAULT FALSE,
    must_change_password BOOLEAN      NOT NULL DEFAULT FALSE,
    banned_until         TIMESTAMPTZ,
    ban_reason           VARCHAR(255) NOT NULL DEFAULT '',
    failed_attempts      INT          NOT NULL DEFAULT 0,
    locked_until         TIMESTAMPTZ,
    last_login_at        TIMESTAMPTZ,
    last_login_ip        VARCHAR(64)  NOT NULL DEFAULT '',
    remark               VARCHAR(500) NOT NULL DEFAULT '',
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT now(),
    deleted_at           TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_sys_user_username
    ON sys_user (username) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_sys_user_dept_id ON sys_user (dept_id);

-- ---------------------------------------------------------------------------
-- 5. 用户-岗位
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_user_post (
    user_id BIGINT NOT NULL,
    post_id BIGINT NOT NULL,
    PRIMARY KEY (user_id, post_id)
);
CREATE INDEX IF NOT EXISTS idx_sys_user_post_post_id ON sys_user_post (post_id);

-- ---------------------------------------------------------------------------
-- 6. 角色
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_role (
    id          BIGSERIAL PRIMARY KEY,
    code        VARCHAR(64)  NOT NULL,
    name        VARCHAR(64)  NOT NULL,
    sort        INT          NOT NULL DEFAULT 0,
    status      SMALLINT     NOT NULL DEFAULT 1,
    remark      VARCHAR(500) NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    deleted_at  TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_sys_role_code
    ON sys_role (code) WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------------
-- 7. 菜单 / 按钮
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_menu (
    id          BIGSERIAL PRIMARY KEY,
    parent_id   BIGINT       NOT NULL DEFAULT 0,
    name        VARCHAR(64)  NOT NULL,
    type        VARCHAR(16)  NOT NULL DEFAULT 'menu', -- dir / menu / button
    path        VARCHAR(255) NOT NULL DEFAULT '',
    component   VARCHAR(255) NOT NULL DEFAULT '',
    permission  VARCHAR(128) NOT NULL DEFAULT '',
    icon        VARCHAR(64)  NOT NULL DEFAULT '',
    sort        INT          NOT NULL DEFAULT 0,
    visible     BOOLEAN      NOT NULL DEFAULT TRUE,
    status      SMALLINT     NOT NULL DEFAULT 1,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    deleted_at  TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_sys_menu_parent_id ON sys_menu (parent_id);
CREATE INDEX IF NOT EXISTS idx_sys_menu_permission ON sys_menu (permission);

-- ---------------------------------------------------------------------------
-- 8. 用户-角色 / 角色-菜单
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_user_role (
    user_id BIGINT NOT NULL,
    role_id BIGINT NOT NULL,
    PRIMARY KEY (user_id, role_id)
);
CREATE INDEX IF NOT EXISTS idx_sys_user_role_role_id ON sys_user_role (role_id);

CREATE TABLE IF NOT EXISTS sys_role_menu (
    role_id BIGINT NOT NULL,
    menu_id BIGINT NOT NULL,
    PRIMARY KEY (role_id, menu_id)
);
CREATE INDEX IF NOT EXISTS idx_sys_role_menu_menu_id ON sys_role_menu (menu_id);

-- ---------------------------------------------------------------------------
-- 9. 字典
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_dict_type (
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(64)  NOT NULL,
    type        VARCHAR(64)  NOT NULL,
    status      SMALLINT     NOT NULL DEFAULT 1,
    remark      VARCHAR(500) NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    deleted_at  TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_sys_dict_type_type
    ON sys_dict_type (type) WHERE deleted_at IS NULL;

CREATE TABLE IF NOT EXISTS sys_dict_item (
    id          BIGSERIAL PRIMARY KEY,
    type_code   VARCHAR(64)  NOT NULL,
    label       VARCHAR(64)  NOT NULL,
    value       VARCHAR(128) NOT NULL,
    sort        INT          NOT NULL DEFAULT 0,
    tag_type    VARCHAR(32)  NOT NULL DEFAULT '',
    status      SMALLINT     NOT NULL DEFAULT 1,
    remark      VARCHAR(500) NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    deleted_at  TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_sys_dict_item_type_value
    ON sys_dict_item (type_code, value) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_sys_dict_item_type_code ON sys_dict_item (type_code);

-- ---------------------------------------------------------------------------
-- 10. 系统配置
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_config (
    id          BIGSERIAL PRIMARY KEY,
    name        VARCHAR(64)   NOT NULL,
    key         VARCHAR(128)  NOT NULL,
    value       VARCHAR(2000) NOT NULL DEFAULT '',
    type        VARCHAR(32)   NOT NULL DEFAULT 'string',
    remark      VARCHAR(500)  NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ   NOT NULL DEFAULT now(),
    deleted_at  TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_sys_config_key
    ON sys_config (key) WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------------
-- 11. 操作日志 / 登录日志（不软删除）
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_oper_log (
    id          BIGSERIAL PRIMARY KEY,
    user_id     BIGINT       NOT NULL DEFAULT 0,
    username    VARCHAR(64)  NOT NULL DEFAULT '',
    dept_id     BIGINT       NOT NULL DEFAULT 0,
    post_id     BIGINT       NOT NULL DEFAULT 0,
    module      VARCHAR(64)  NOT NULL DEFAULT '',
    action      VARCHAR(64)  NOT NULL DEFAULT '',
    method      VARCHAR(16)  NOT NULL DEFAULT '',
    path        VARCHAR(255) NOT NULL DEFAULT '',
    ip          VARCHAR(64)  NOT NULL DEFAULT '',
    ua          VARCHAR(500) NOT NULL DEFAULT '',
    code        INT          NOT NULL DEFAULT 0,
    duration_ms BIGINT       NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_sys_oper_log_created_at ON sys_oper_log (created_at);
CREATE INDEX IF NOT EXISTS idx_sys_oper_log_user_id ON sys_oper_log (user_id);
CREATE INDEX IF NOT EXISTS idx_sys_oper_log_dept_id ON sys_oper_log (dept_id);
CREATE INDEX IF NOT EXISTS idx_sys_oper_log_post_id ON sys_oper_log (post_id);

CREATE TABLE IF NOT EXISTS sys_login_log (
    id         BIGSERIAL PRIMARY KEY,
    username   VARCHAR(64)  NOT NULL DEFAULT '',
    dept_id    BIGINT       NOT NULL DEFAULT 0,
    post_id    BIGINT       NOT NULL DEFAULT 0,
    ip         VARCHAR(64)  NOT NULL DEFAULT '',
    ua         VARCHAR(500) NOT NULL DEFAULT '',
    status     SMALLINT     NOT NULL DEFAULT 1,
    message    VARCHAR(255) NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_sys_login_log_created_at ON sys_login_log (created_at);
CREATE INDEX IF NOT EXISTS idx_sys_login_log_username ON sys_login_log (username);
CREATE INDEX IF NOT EXISTS idx_sys_login_log_dept_id ON sys_login_log (dept_id);
CREATE INDEX IF NOT EXISTS idx_sys_login_log_post_id ON sys_login_log (post_id);

-- ---------------------------------------------------------------------------
-- 12. 文件
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_file (
    id            BIGSERIAL PRIMARY KEY,
    original_name VARCHAR(255) NOT NULL DEFAULT '',
    object_key    VARCHAR(500) NOT NULL DEFAULT '',
    url           VARCHAR(1000) NOT NULL DEFAULT '',
    size          BIGINT       NOT NULL DEFAULT 0,
    mime          VARCHAR(128) NOT NULL DEFAULT '',
    storage       VARCHAR(32)  NOT NULL DEFAULT 'local',
    uploader_id   BIGINT       NOT NULL DEFAULT 0,
    dept_id       BIGINT       NOT NULL DEFAULT 0,
    post_id       BIGINT       NOT NULL DEFAULT 0,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    deleted_at    TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_sys_file_uploader_id ON sys_file (uploader_id);
CREATE INDEX IF NOT EXISTS idx_sys_file_dept_id ON sys_file (dept_id);
CREATE INDEX IF NOT EXISTS idx_sys_file_post_id ON sys_file (post_id);

-- ---------------------------------------------------------------------------
-- 13. 通知 / 通知接收人
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_notice (
    id           BIGSERIAL PRIMARY KEY,
    title        VARCHAR(255) NOT NULL,
    content      TEXT         NOT NULL DEFAULT '',
    type         VARCHAR(16)  NOT NULL DEFAULT 'notice',
    target_type  VARCHAR(16)  NOT NULL DEFAULT 'all',
    status       SMALLINT     NOT NULL DEFAULT 0, -- 0 草稿 / 1 已发布
    sender_id    BIGINT       NOT NULL DEFAULT 0,
    dept_id      BIGINT       NOT NULL DEFAULT 0,
    post_id      BIGINT       NOT NULL DEFAULT 0,
    published_at TIMESTAMPTZ,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    deleted_at   TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_sys_notice_dept_id ON sys_notice (dept_id);
CREATE INDEX IF NOT EXISTS idx_sys_notice_post_id ON sys_notice (post_id);
CREATE INDEX IF NOT EXISTS idx_sys_notice_status_published ON sys_notice (status, published_at);

CREATE TABLE IF NOT EXISTS sys_notice_receiver (
    id         BIGSERIAL PRIMARY KEY,
    notice_id  BIGINT      NOT NULL,
    user_id    BIGINT      NOT NULL,
    read_at    TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (notice_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_sys_notice_receiver_user_read
    ON sys_notice_receiver (user_id, read_at);

-- ---------------------------------------------------------------------------
-- 14. 种子数据
-- ---------------------------------------------------------------------------
-- 默认账号：admin / Admin@123456，首次登录强制改密。
-- 菜单与按钮权限种子在阶段 3/4 实现 RBAC 时补充。

INSERT INTO sys_dept (id, parent_id, ancestors, name, sort, status)
VALUES (1, 0, '0', '总部', 1, 1)
ON CONFLICT DO NOTHING;

INSERT INTO sys_role (id, code, name, sort, status)
VALUES (1, 'admin', '超级管理员', 1, 1)
ON CONFLICT DO NOTHING;

INSERT INTO sys_user (
    id, username, password_hash, nickname, dept_id, status,
    is_super, must_change_password
) VALUES (
    1, 'admin',
    '$2a$10$GMu7XmovGjP4veNplguZXurI1rGKGgQxdxmpubMz5vmssC3OWyBYi',
    '超级管理员', 1, 1, TRUE, TRUE
)
ON CONFLICT DO NOTHING;

INSERT INTO sys_user_role (user_id, role_id)
VALUES (1, 1)
ON CONFLICT DO NOTHING;

-- 显式写入 id 后同步序列，避免后续自增主键冲突。
SELECT setval(pg_get_serial_sequence('sys_dept', 'id'),
              COALESCE((SELECT MAX(id) FROM sys_dept), 1));
SELECT setval(pg_get_serial_sequence('sys_role', 'id'),
              COALESCE((SELECT MAX(id) FROM sys_role), 1));
SELECT setval(pg_get_serial_sequence('sys_user', 'id'),
              COALESCE((SELECT MAX(id) FROM sys_user), 1));

COMMIT;

\echo 'Hecc-Admin-Go 数据库初始化完成（database = hecc-admin）。'
