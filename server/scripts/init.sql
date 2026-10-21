-- Hecc-Admin-Go PostgreSQL 初始化脚本
--
-- 纯 SQL 脚本，不使用 psql 元命令，psql / GoLand / DataGrip 均可执行。
--
-- 执行前需先连接到 hecc-admin 数据库（本脚本不建库、不切库）。
-- 数据库不存在时先手动创建：
--   CREATE DATABASE "hecc-admin" WITH ENCODING 'UTF8' TEMPLATE template0;
--
-- 执行方式：
--   psql   ：psql -h 127.0.0.1 -U postgres -d hecc-admin -f scripts/init.sql
--   GoLand ：数据源指向 hecc-admin，打开本文件右键 Run
--
-- 脚本可重复执行：
--   - 表、索引均使用 IF NOT EXISTS；
--   - 种子数据使用 ON CONFLICT DO NOTHING。
--
-- 项目不使用 Go 迁移工具，表结构以本文件为准。修改模型时请同步修改这里，
-- 并保持 GORM 模型（server/entity/model）的列名与本文件一致。
--
-- 表清单（速查）：
--   sys_dept              部门，组织架构树
--   sys_post              岗位
--   sys_user              用户账号，含登录风控字段
--   sys_user_post         用户-岗位关联（多对多）
--   sys_role              角色
--   sys_menu              菜单 / 按钮，RBAC 权限点
--   sys_user_role         用户-角色关联（多对多）
--   sys_role_menu         角色-菜单关联（多对多）
--   sys_dict_type         字典类型
--   sys_dict_item         字典项
--   sys_config            系统配置（键值对）
--   sys_oper_log          操作日志（不软删除）
--   sys_login_log         登录日志（不软删除）
--   sys_file              上传文件元信息
--   sys_notice            通知公告
--   sys_notice_receiver   通知接收人及已读状态
--
-- 通用约定：
--   - 所有表主键统一为 BIGSERIAL 自增 id，且都带 created_at / updated_at；
--     关联表用唯一索引（如 sys_user_post 的 user_id + post_id）保证不重复；
--   - 所有时间字段统一为 BIGINT，存 Unix 秒；created_at / updated_at 由
--     数据库默认值和 GORM autoCreateTime / autoUpdateTime 维护；
--   - 业务时间字段（封禁、锁定、最后登录、发布、已读）取 0 表示未设置；
--   - deleted_at = 0 表示未删除，软删除由 gorm.io/plugin/soft_delete 处理；
--     软删除表的唯一索引均为部分索引（WHERE deleted_at = 0），
--     使记录删除后可重建同名数据；
--   - 关联字段取 0 表示未关联（如 dept_id = 0 表示未分配部门），
--     不使用 NULL，便于查询时免去判空；
--   - 日志、文件、通知表冗余 dept_id / post_id，用于数据权限过滤，
--     属于写入时快照，不随用户后续调岗变化。
--
-- 每张表和每个字段的说明以 COMMENT ON 写入数据库，可用以下命令查看：
--   psql -d "hecc-admin" -c '\d+ sys_user'

-- 固定客户端编码，避免 Windows 中文控制台下注释文案乱码。
SET client_encoding = 'UTF8';

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. 部门
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_dept
(
    id         BIGSERIAL PRIMARY KEY,
    parent_id  BIGINT       NOT NULL DEFAULT 0,
    ancestors  BIGINT[]     NOT NULL DEFAULT '{}'::bigint[], -- 形如 {0,1,3}，含根 0、不含自身
    name       VARCHAR(64)  NOT NULL,
    leader_id  BIGINT       NOT NULL DEFAULT 0,   -- 关联 sys_user.id，0 表示未关联
    leader     VARCHAR(64)  NOT NULL DEFAULT '',  -- 负责人姓名快照
    phone      VARCHAR(32)  NOT NULL DEFAULT '',  -- 部门联系电话
    email      VARCHAR(128) NOT NULL DEFAULT '',  -- 部门邮箱
    sort       INT          NOT NULL DEFAULT 0,
    status     SMALLINT     NOT NULL DEFAULT 1,   -- 0 禁用 / 1 启用
    created_at BIGINT       NOT NULL DEFAULT (extract(epoch from now())::bigint),
    updated_at BIGINT       NOT NULL DEFAULT (extract(epoch from now())::bigint),
    deleted_at BIGINT NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_sys_dept_parent_id ON sys_dept (parent_id);
CREATE INDEX IF NOT EXISTS idx_sys_dept_ancestors ON sys_dept USING GIN (ancestors);
CREATE INDEX IF NOT EXISTS idx_sys_dept_leader_id ON sys_dept (leader_id);

COMMENT ON TABLE sys_dept IS '部门表：组织架构树，支持任意层级';
COMMENT ON COLUMN sys_dept.id IS '主键';
COMMENT ON COLUMN sys_dept.parent_id IS '上级部门 ID，0 表示顶级部门';
COMMENT ON COLUMN sys_dept.ancestors IS '祖级链路（如 {0,1,3}），含根 0、不含自身，用 @> 查询子孙部门';
COMMENT ON COLUMN sys_dept.name IS '部门名称';
COMMENT ON COLUMN sys_dept.leader_id IS '负责人用户 ID，关联 sys_user.id；0 表示未关联或无系统账号';
COMMENT ON COLUMN sys_dept.leader IS '负责人姓名（展示快照，不随用户改名自动变化）';
COMMENT ON COLUMN sys_dept.phone IS '部门联系电话（非负责人个人手机号）';
COMMENT ON COLUMN sys_dept.email IS '部门邮箱（非负责人个人邮箱）';
COMMENT ON COLUMN sys_dept.sort IS '同层级排序值，升序';
COMMENT ON COLUMN sys_dept.status IS '状态：0 禁用 / 1 启用';
COMMENT ON COLUMN sys_dept.created_at IS '创建时间（Unix 秒）';
COMMENT ON COLUMN sys_dept.updated_at IS '更新时间（Unix 秒）';
COMMENT ON COLUMN sys_dept.deleted_at IS '软删除标记（Unix 秒），0 表示未删除';

-- ---------------------------------------------------------------------------
-- 2. 岗位
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_post
(
    id         BIGSERIAL PRIMARY KEY,
    code       VARCHAR(64)  NOT NULL,
    name       VARCHAR(64)  NOT NULL,
    sort       INT          NOT NULL DEFAULT 0,
    status     SMALLINT     NOT NULL DEFAULT 1,
    remark     VARCHAR(500) NOT NULL DEFAULT '',
    created_at BIGINT       NOT NULL DEFAULT (extract(epoch from now())::bigint),
    updated_at BIGINT       NOT NULL DEFAULT (extract(epoch from now())::bigint),
    deleted_at BIGINT NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_sys_post_code
    ON sys_post (code) WHERE deleted_at = 0;

COMMENT ON TABLE sys_post IS '岗位表：用户的职务标签，主要用于数据权限与日志快照';
COMMENT ON COLUMN sys_post.id IS '主键';
COMMENT ON COLUMN sys_post.code IS '岗位编码，全局唯一（软删除后可复用）';
COMMENT ON COLUMN sys_post.name IS '岗位名称';
COMMENT ON COLUMN sys_post.sort IS '排序值，升序';
COMMENT ON COLUMN sys_post.status IS '状态：0 禁用 / 1 启用';
COMMENT ON COLUMN sys_post.remark IS '备注';
COMMENT ON COLUMN sys_post.created_at IS '创建时间（Unix 秒）';
COMMENT ON COLUMN sys_post.updated_at IS '更新时间（Unix 秒）';
COMMENT ON COLUMN sys_post.deleted_at IS '软删除标记（Unix 秒），0 表示未删除';

-- ---------------------------------------------------------------------------
-- 3. 用户
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_user
(
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
    banned_until         BIGINT     NOT NULL DEFAULT 0,
    ban_reason           VARCHAR(255) NOT NULL DEFAULT '',
    failed_attempts      INT          NOT NULL DEFAULT 0,
    locked_until         BIGINT     NOT NULL DEFAULT 0,
    last_login_at        BIGINT     NOT NULL DEFAULT 0,
    last_login_ip        VARCHAR(64)  NOT NULL DEFAULT '',
    remark               VARCHAR(500) NOT NULL DEFAULT '',
    created_at           BIGINT       NOT NULL DEFAULT (extract(epoch from now())::bigint),
    updated_at           BIGINT       NOT NULL DEFAULT (extract(epoch from now())::bigint),
    deleted_at           BIGINT NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_sys_user_username
    ON sys_user (username) WHERE deleted_at = 0;
CREATE INDEX IF NOT EXISTS idx_sys_user_dept_id ON sys_user (dept_id);

COMMENT ON TABLE sys_user IS '用户表：登录账号、资料与登录风控状态';
COMMENT ON COLUMN sys_user.id IS '主键';
COMMENT ON COLUMN sys_user.username IS '登录名，全局唯一（软删除后可复用）';
COMMENT ON COLUMN sys_user.password_hash IS '密码哈希（bcrypt），不存明文';
COMMENT ON COLUMN sys_user.nickname IS '昵称 / 显示名';
COMMENT ON COLUMN sys_user.email IS '邮箱';
COMMENT ON COLUMN sys_user.phone IS '手机号';
COMMENT ON COLUMN sys_user.avatar IS '头像 URL';
COMMENT ON COLUMN sys_user.dept_id IS '所属部门 ID，0 表示未分配';
COMMENT ON COLUMN sys_user.status IS '账号状态：0 禁用 / 1 启用（禁用后不可登录）';
COMMENT ON COLUMN sys_user.is_super IS '是否超级管理员，为真时跳过权限校验';
COMMENT ON COLUMN sys_user.must_change_password IS '是否强制下次登录修改密码';
COMMENT ON COLUMN sys_user.banned_until IS '封禁截止时间（Unix 秒），0 表示未封禁';
COMMENT ON COLUMN sys_user.ban_reason IS '封禁原因';
COMMENT ON COLUMN sys_user.failed_attempts IS '连续登录失败次数，登录成功后清零';
COMMENT ON COLUMN sys_user.locked_until IS '因失败次数过多触发的临时锁定截止时间（Unix 秒），0 表示未锁定';
COMMENT ON COLUMN sys_user.last_login_at IS '最后登录时间（Unix 秒），0 表示从未登录';
COMMENT ON COLUMN sys_user.last_login_ip IS '最后登录 IP';
COMMENT ON COLUMN sys_user.remark IS '备注';
COMMENT ON COLUMN sys_user.created_at IS '创建时间（Unix 秒）';
COMMENT ON COLUMN sys_user.updated_at IS '更新时间（Unix 秒）';
COMMENT ON COLUMN sys_user.deleted_at IS '软删除标记（Unix 秒），0 表示未删除';

-- ---------------------------------------------------------------------------
-- 4. 用户-岗位
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_user_post
(
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT NOT NULL,
    post_id    BIGINT NOT NULL,
    created_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint),
    updated_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_sys_user_post_user_post
    ON sys_user_post (user_id, post_id);
CREATE INDEX IF NOT EXISTS idx_sys_user_post_post_id ON sys_user_post (post_id);

COMMENT ON TABLE sys_user_post IS '用户-岗位关联表，多对多；user_id + post_id 唯一';
COMMENT ON COLUMN sys_user_post.id IS '主键';
COMMENT ON COLUMN sys_user_post.user_id IS '用户 ID，关联 sys_user.id';
COMMENT ON COLUMN sys_user_post.post_id IS '岗位 ID，关联 sys_post.id';
COMMENT ON COLUMN sys_user_post.created_at IS '创建时间（Unix 秒）';
COMMENT ON COLUMN sys_user_post.updated_at IS '更新时间（Unix 秒）';

-- ---------------------------------------------------------------------------
-- 5. 角色
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_role
(
    id         BIGSERIAL PRIMARY KEY,
    code       VARCHAR(64)  NOT NULL,
    name       VARCHAR(64)  NOT NULL,
    sort       INT          NOT NULL DEFAULT 0,
    status     SMALLINT     NOT NULL DEFAULT 1,
    remark     VARCHAR(500) NOT NULL DEFAULT '',
    created_at BIGINT       NOT NULL DEFAULT (extract(epoch from now())::bigint),
    updated_at BIGINT       NOT NULL DEFAULT (extract(epoch from now())::bigint),
    deleted_at BIGINT NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_sys_role_code
    ON sys_role (code) WHERE deleted_at = 0;

COMMENT ON TABLE sys_role IS '角色表：权限集合，通过 sys_user_role / sys_role_menu 关联';
COMMENT ON COLUMN sys_role.id IS '主键';
COMMENT ON COLUMN sys_role.code IS '角色编码（如 admin），全局唯一，代码中按此判断';
COMMENT ON COLUMN sys_role.name IS '角色名称';
COMMENT ON COLUMN sys_role.sort IS '排序值，升序';
COMMENT ON COLUMN sys_role.status IS '状态：0 禁用 / 1 启用';
COMMENT ON COLUMN sys_role.remark IS '备注';
COMMENT ON COLUMN sys_role.created_at IS '创建时间（Unix 秒）';
COMMENT ON COLUMN sys_role.updated_at IS '更新时间（Unix 秒）';
COMMENT ON COLUMN sys_role.deleted_at IS '软删除标记（Unix 秒），0 表示未删除';

-- ---------------------------------------------------------------------------
-- 6. 菜单 / 按钮
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_menu
(
    id         BIGSERIAL PRIMARY KEY,
    parent_id  BIGINT       NOT NULL DEFAULT 0,
    name       VARCHAR(64)  NOT NULL,
    type       VARCHAR(16)  NOT NULL DEFAULT 'menu', -- dir / menu / button
    path       VARCHAR(255) NOT NULL DEFAULT '',
    component  VARCHAR(255) NOT NULL DEFAULT '',
    permission VARCHAR(128) NOT NULL DEFAULT '',
    icon       VARCHAR(64)  NOT NULL DEFAULT '',
    sort       INT          NOT NULL DEFAULT 0,
    visible    BOOLEAN      NOT NULL DEFAULT TRUE,
    status     SMALLINT     NOT NULL DEFAULT 1,
    created_at BIGINT       NOT NULL DEFAULT (extract(epoch from now())::bigint),
    updated_at BIGINT       NOT NULL DEFAULT (extract(epoch from now())::bigint),
    deleted_at BIGINT NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_sys_menu_parent_id ON sys_menu (parent_id);
CREATE INDEX IF NOT EXISTS idx_sys_menu_permission ON sys_menu (permission);

COMMENT ON TABLE sys_menu IS '菜单 / 按钮表：前端路由与 RBAC 权限点的统一来源';
COMMENT ON COLUMN sys_menu.id IS '主键';
COMMENT ON COLUMN sys_menu.parent_id IS '上级菜单 ID，0 表示顶级';
COMMENT ON COLUMN sys_menu.name IS '菜单 / 按钮名称';
COMMENT ON COLUMN sys_menu.type IS '类型：dir 目录 / menu 菜单 / button 按钮（按钮仅作权限点，无路由）';
COMMENT ON COLUMN sys_menu.path IS '前端路由路径';
COMMENT ON COLUMN sys_menu.component IS '前端组件路径，目录类型为空';
COMMENT ON COLUMN sys_menu.permission IS '权限标识（如 system:user:add），按钮类型必填，用于接口鉴权';
COMMENT ON COLUMN sys_menu.icon IS '菜单图标';
COMMENT ON COLUMN sys_menu.sort IS '同层级排序值，升序';
COMMENT ON COLUMN sys_menu.visible IS '是否在侧边栏显示，false 表示隐藏但仍可访问';
COMMENT ON COLUMN sys_menu.status IS '状态：0 禁用 / 1 启用';
COMMENT ON COLUMN sys_menu.created_at IS '创建时间（Unix 秒）';
COMMENT ON COLUMN sys_menu.updated_at IS '更新时间（Unix 秒）';
COMMENT ON COLUMN sys_menu.deleted_at IS '软删除标记（Unix 秒），0 表示未删除';

-- ---------------------------------------------------------------------------
-- 7. 用户-角色 / 角色-菜单
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_user_role
(
    id         BIGSERIAL PRIMARY KEY,
    user_id    BIGINT NOT NULL,
    role_id    BIGINT NOT NULL,
    created_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint),
    updated_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_sys_user_role_user_role
    ON sys_user_role (user_id, role_id);
CREATE INDEX IF NOT EXISTS idx_sys_user_role_role_id ON sys_user_role (role_id);

CREATE TABLE IF NOT EXISTS sys_role_menu
(
    id         BIGSERIAL PRIMARY KEY,
    role_id    BIGINT NOT NULL,
    menu_id    BIGINT NOT NULL,
    created_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint),
    updated_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_sys_role_menu_role_menu
    ON sys_role_menu (role_id, menu_id);
CREATE INDEX IF NOT EXISTS idx_sys_role_menu_menu_id ON sys_role_menu (menu_id);

COMMENT ON TABLE sys_user_role IS '用户-角色关联表，多对多；user_id + role_id 唯一';
COMMENT ON COLUMN sys_user_role.id IS '主键';
COMMENT ON COLUMN sys_user_role.user_id IS '用户 ID，关联 sys_user.id';
COMMENT ON COLUMN sys_user_role.role_id IS '角色 ID，关联 sys_role.id';
COMMENT ON COLUMN sys_user_role.created_at IS '创建时间（Unix 秒）';
COMMENT ON COLUMN sys_user_role.updated_at IS '更新时间（Unix 秒）';

COMMENT ON TABLE sys_role_menu IS '角色-菜单关联表，多对多；role_id + menu_id 唯一';
COMMENT ON COLUMN sys_role_menu.id IS '主键';
COMMENT ON COLUMN sys_role_menu.role_id IS '角色 ID，关联 sys_role.id';
COMMENT ON COLUMN sys_role_menu.menu_id IS '菜单 / 按钮 ID，关联 sys_menu.id';
COMMENT ON COLUMN sys_role_menu.created_at IS '创建时间（Unix 秒）';
COMMENT ON COLUMN sys_role_menu.updated_at IS '更新时间（Unix 秒）';

-- ---------------------------------------------------------------------------
-- 8. 字典
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_dict_type
(
    id         BIGSERIAL PRIMARY KEY,
    name       VARCHAR(64)  NOT NULL,
    type       VARCHAR(64)  NOT NULL,
    status     SMALLINT     NOT NULL DEFAULT 1,
    remark     VARCHAR(500) NOT NULL DEFAULT '',
    created_at BIGINT       NOT NULL DEFAULT (extract(epoch from now())::bigint),
    updated_at BIGINT       NOT NULL DEFAULT (extract(epoch from now())::bigint),
    deleted_at BIGINT NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_sys_dict_type_type
    ON sys_dict_type (type) WHERE deleted_at = 0;

COMMENT ON TABLE sys_dict_type IS '字典类型表：一组枚举值的分类';
COMMENT ON COLUMN sys_dict_type.id IS '主键';
COMMENT ON COLUMN sys_dict_type.name IS '字典名称，供管理端展示';
COMMENT ON COLUMN sys_dict_type.type IS '字典类型编码，全局唯一，sys_dict_item.type_code 引用此值';
COMMENT ON COLUMN sys_dict_type.status IS '状态：0 禁用 / 1 启用';
COMMENT ON COLUMN sys_dict_type.remark IS '备注';
COMMENT ON COLUMN sys_dict_type.created_at IS '创建时间（Unix 秒）';
COMMENT ON COLUMN sys_dict_type.updated_at IS '更新时间（Unix 秒）';
COMMENT ON COLUMN sys_dict_type.deleted_at IS '软删除标记（Unix 秒），0 表示未删除';

CREATE TABLE IF NOT EXISTS sys_dict_item
(
    id         BIGSERIAL PRIMARY KEY,
    type_code  VARCHAR(64)  NOT NULL,
    label      VARCHAR(64)  NOT NULL,
    value      VARCHAR(128) NOT NULL,
    sort       INT          NOT NULL DEFAULT 0,
    tag_type   VARCHAR(32)  NOT NULL DEFAULT '',
    status     SMALLINT     NOT NULL DEFAULT 1,
    remark     VARCHAR(500) NOT NULL DEFAULT '',
    created_at BIGINT       NOT NULL DEFAULT (extract(epoch from now())::bigint),
    updated_at BIGINT       NOT NULL DEFAULT (extract(epoch from now())::bigint),
    deleted_at BIGINT NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_sys_dict_item_type_value
    ON sys_dict_item (type_code, value) WHERE deleted_at = 0;
CREATE INDEX IF NOT EXISTS idx_sys_dict_item_type_code ON sys_dict_item (type_code);

COMMENT ON TABLE sys_dict_item IS '字典项表：字典类型下的具体取值';
COMMENT ON COLUMN sys_dict_item.id IS '主键';
COMMENT ON COLUMN sys_dict_item.type_code IS '所属字典类型编码，逻辑关联 sys_dict_type.type（不建外键）';
COMMENT ON COLUMN sys_dict_item.label IS '展示文案';
COMMENT ON COLUMN sys_dict_item.value IS '实际存储值，同一类型下唯一';
COMMENT ON COLUMN sys_dict_item.sort IS '同类型内排序值，升序';
COMMENT ON COLUMN sys_dict_item.tag_type IS '前端标签样式（如 success / warning / danger），空表示普通文本';
COMMENT ON COLUMN sys_dict_item.status IS '状态：0 禁用 / 1 启用';
COMMENT ON COLUMN sys_dict_item.remark IS '备注';
COMMENT ON COLUMN sys_dict_item.created_at IS '创建时间（Unix 秒）';
COMMENT ON COLUMN sys_dict_item.updated_at IS '更新时间（Unix 秒）';
COMMENT ON COLUMN sys_dict_item.deleted_at IS '软删除标记（Unix 秒），0 表示未删除';

-- ---------------------------------------------------------------------------
-- 9. 系统配置
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_config
(
    id         BIGSERIAL PRIMARY KEY,
    name       VARCHAR(64)   NOT NULL,
    key        VARCHAR(128)  NOT NULL,
    value      VARCHAR(2000) NOT NULL DEFAULT '',
    type       VARCHAR(32)   NOT NULL DEFAULT 'string',
    remark     VARCHAR(500)  NOT NULL DEFAULT '',
    created_at BIGINT        NOT NULL DEFAULT (extract(epoch from now())::bigint),
    updated_at BIGINT        NOT NULL DEFAULT (extract(epoch from now())::bigint),
    deleted_at BIGINT NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_sys_config_key
    ON sys_config (key) WHERE deleted_at = 0;

COMMENT ON TABLE sys_config IS '系统配置表：运行期可改的键值对参数';
COMMENT ON COLUMN sys_config.id IS '主键';
COMMENT ON COLUMN sys_config.name IS '配置名称，供管理端展示';
COMMENT ON COLUMN sys_config.key IS '配置键，全局唯一，代码中按此读取';
COMMENT ON COLUMN sys_config.value IS '配置值，统一以字符串存储，按 type 解析';
COMMENT ON COLUMN sys_config.type IS '值类型：string / number / boolean / json';
COMMENT ON COLUMN sys_config.remark IS '备注';
COMMENT ON COLUMN sys_config.created_at IS '创建时间（Unix 秒）';
COMMENT ON COLUMN sys_config.updated_at IS '更新时间（Unix 秒）';
COMMENT ON COLUMN sys_config.deleted_at IS '软删除标记（Unix 秒），0 表示未删除';

-- ---------------------------------------------------------------------------
-- 10. 操作日志 / 登录日志（不软删除）
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_oper_log
(
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
    created_at  BIGINT       NOT NULL DEFAULT (extract(epoch from now())::bigint),
    updated_at  BIGINT       NOT NULL DEFAULT (extract(epoch from now())::bigint)
);
CREATE INDEX IF NOT EXISTS idx_sys_oper_log_created_at ON sys_oper_log (created_at);
CREATE INDEX IF NOT EXISTS idx_sys_oper_log_user_id ON sys_oper_log (user_id);
CREATE INDEX IF NOT EXISTS idx_sys_oper_log_dept_id ON sys_oper_log (dept_id);
CREATE INDEX IF NOT EXISTS idx_sys_oper_log_post_id ON sys_oper_log (post_id);

COMMENT ON TABLE sys_oper_log IS '操作日志表：写操作审计，只追加不更新、不软删除';
COMMENT ON COLUMN sys_oper_log.id IS '主键';
COMMENT ON COLUMN sys_oper_log.user_id IS '操作人用户 ID，0 表示未登录 / 匿名';
COMMENT ON COLUMN sys_oper_log.username IS '操作人登录名快照';
COMMENT ON COLUMN sys_oper_log.dept_id IS '操作人所属部门快照，用于数据权限过滤';
COMMENT ON COLUMN sys_oper_log.post_id IS '操作人所属岗位快照，用于数据权限过滤';
COMMENT ON COLUMN sys_oper_log.module IS '业务模块（如 用户管理）';
COMMENT ON COLUMN sys_oper_log.action IS '操作类型（如 新增 / 修改 / 删除）';
COMMENT ON COLUMN sys_oper_log.method IS 'HTTP 方法';
COMMENT ON COLUMN sys_oper_log.path IS '请求路径';
COMMENT ON COLUMN sys_oper_log.ip IS '客户端 IP';
COMMENT ON COLUMN sys_oper_log.ua IS '客户端 User-Agent';
COMMENT ON COLUMN sys_oper_log.code IS '响应业务码，0 表示成功';
COMMENT ON COLUMN sys_oper_log.duration_ms IS '处理耗时，毫秒';
COMMENT ON COLUMN sys_oper_log.created_at IS '操作时间（Unix 秒）';
COMMENT ON COLUMN sys_oper_log.updated_at IS '更新时间（Unix 秒），日志不更新，与 created_at 相同';

CREATE TABLE IF NOT EXISTS sys_login_log
(
    id         BIGSERIAL PRIMARY KEY,
    username   VARCHAR(64)  NOT NULL DEFAULT '',
    dept_id    BIGINT       NOT NULL DEFAULT 0,
    post_id    BIGINT       NOT NULL DEFAULT 0,
    ip         VARCHAR(64)  NOT NULL DEFAULT '',
    ua         VARCHAR(500) NOT NULL DEFAULT '',
    status     SMALLINT     NOT NULL DEFAULT 1,
    message    VARCHAR(255) NOT NULL DEFAULT '',
    created_at BIGINT       NOT NULL DEFAULT (extract(epoch from now())::bigint),
    updated_at BIGINT       NOT NULL DEFAULT (extract(epoch from now())::bigint)
);
CREATE INDEX IF NOT EXISTS idx_sys_login_log_created_at ON sys_login_log (created_at);
CREATE INDEX IF NOT EXISTS idx_sys_login_log_username ON sys_login_log (username);
CREATE INDEX IF NOT EXISTS idx_sys_login_log_dept_id ON sys_login_log (dept_id);
CREATE INDEX IF NOT EXISTS idx_sys_login_log_post_id ON sys_login_log (post_id);

COMMENT ON TABLE sys_login_log IS '登录日志表：登录成功与失败记录，只追加不更新、不软删除';
COMMENT ON COLUMN sys_login_log.id IS '主键';
COMMENT ON COLUMN sys_login_log.username IS '尝试登录的登录名，失败时可能不存在对应用户';
COMMENT ON COLUMN sys_login_log.dept_id IS '用户所属部门快照，用于数据权限过滤';
COMMENT ON COLUMN sys_login_log.post_id IS '用户所属岗位快照，用于数据权限过滤';
COMMENT ON COLUMN sys_login_log.ip IS '客户端 IP';
COMMENT ON COLUMN sys_login_log.ua IS '客户端 User-Agent';
COMMENT ON COLUMN sys_login_log.status IS '登录结果：0 失败 / 1 成功';
COMMENT ON COLUMN sys_login_log.message IS '结果说明，失败时为错误原因';
COMMENT ON COLUMN sys_login_log.created_at IS '登录时间（Unix 秒）';
COMMENT ON COLUMN sys_login_log.updated_at IS '更新时间（Unix 秒），日志不更新，与 created_at 相同';

-- ---------------------------------------------------------------------------
-- 11. 文件
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_file
(
    id            BIGSERIAL PRIMARY KEY,
    original_name VARCHAR(255)  NOT NULL DEFAULT '',
    object_key    VARCHAR(500)  NOT NULL DEFAULT '',
    url           VARCHAR(1000) NOT NULL DEFAULT '',
    size          BIGINT        NOT NULL DEFAULT 0,
    mime          VARCHAR(128)  NOT NULL DEFAULT '',
    storage       VARCHAR(32)   NOT NULL DEFAULT 'local',
    uploader_id   BIGINT        NOT NULL DEFAULT 0,
    dept_id       BIGINT        NOT NULL DEFAULT 0,
    post_id       BIGINT        NOT NULL DEFAULT 0,
    created_at    BIGINT        NOT NULL DEFAULT (extract(epoch from now())::bigint),
    updated_at    BIGINT        NOT NULL DEFAULT (extract(epoch from now())::bigint),
    deleted_at    BIGINT NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_sys_file_uploader_id ON sys_file (uploader_id);
CREATE INDEX IF NOT EXISTS idx_sys_file_dept_id ON sys_file (dept_id);
CREATE INDEX IF NOT EXISTS idx_sys_file_post_id ON sys_file (post_id);

COMMENT ON TABLE sys_file IS '文件表：上传文件的元信息，文件内容存于本地或对象存储';
COMMENT ON COLUMN sys_file.id IS '主键';
COMMENT ON COLUMN sys_file.original_name IS '原始文件名，供下载时还原';
COMMENT ON COLUMN sys_file.object_key IS '存储对象键 / 相对路径，定位实际文件';
COMMENT ON COLUMN sys_file.url IS '对外访问 URL';
COMMENT ON COLUMN sys_file.size IS '文件大小，字节';
COMMENT ON COLUMN sys_file.mime IS 'MIME 类型';
COMMENT ON COLUMN sys_file.storage IS '存储位置：local 本地 / oss 对象存储';
COMMENT ON COLUMN sys_file.uploader_id IS '上传人用户 ID';
COMMENT ON COLUMN sys_file.dept_id IS '上传人所属部门快照，用于数据权限过滤';
COMMENT ON COLUMN sys_file.post_id IS '上传人所属岗位快照，用于数据权限过滤';
COMMENT ON COLUMN sys_file.created_at IS '上传时间（Unix 秒）';
COMMENT ON COLUMN sys_file.updated_at IS '更新时间（Unix 秒）';
COMMENT ON COLUMN sys_file.deleted_at IS '软删除标记（Unix 秒），0 表示未删除';

-- ---------------------------------------------------------------------------
-- 12. 通知 / 通知接收人
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sys_notice
(
    id           BIGSERIAL PRIMARY KEY,
    title        VARCHAR(255) NOT NULL,
    content      TEXT         NOT NULL DEFAULT '',
    type         VARCHAR(16)  NOT NULL DEFAULT 'notice',
    target_type  VARCHAR(16)  NOT NULL DEFAULT 'all',
    status       SMALLINT     NOT NULL DEFAULT 0, -- 0 草稿 / 1 已发布
    sender_id    BIGINT       NOT NULL DEFAULT 0,
    dept_id      BIGINT       NOT NULL DEFAULT 0,
    post_id      BIGINT       NOT NULL DEFAULT 0,
    published_at BIGINT     NOT NULL DEFAULT 0,
    created_at   BIGINT       NOT NULL DEFAULT (extract(epoch from now())::bigint),
    updated_at   BIGINT       NOT NULL DEFAULT (extract(epoch from now())::bigint),
    deleted_at   BIGINT NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_sys_notice_dept_id ON sys_notice (dept_id);
CREATE INDEX IF NOT EXISTS idx_sys_notice_post_id ON sys_notice (post_id);
CREATE INDEX IF NOT EXISTS idx_sys_notice_status_published ON sys_notice (status, published_at);

COMMENT ON TABLE sys_notice IS '通知公告表：先存草稿，发布后按目标范围投递到 sys_notice_receiver';
COMMENT ON COLUMN sys_notice.id IS '主键';
COMMENT ON COLUMN sys_notice.title IS '标题';
COMMENT ON COLUMN sys_notice.content IS '正文，支持富文本 / Markdown';
COMMENT ON COLUMN sys_notice.type IS '通知类型：notice 通知 / announcement 公告';
COMMENT ON COLUMN sys_notice.target_type IS '接收范围：all 全体 / dept 按部门 / user 指定用户';
COMMENT ON COLUMN sys_notice.status IS '状态：0 草稿 / 1 已发布';
COMMENT ON COLUMN sys_notice.sender_id IS '发布人用户 ID';
COMMENT ON COLUMN sys_notice.dept_id IS '发布人所属部门快照，用于数据权限过滤';
COMMENT ON COLUMN sys_notice.post_id IS '发布人所属岗位快照，用于数据权限过滤';
COMMENT ON COLUMN sys_notice.published_at IS '发布时间（Unix 秒），草稿为 0';
COMMENT ON COLUMN sys_notice.created_at IS '创建时间（Unix 秒）';
COMMENT ON COLUMN sys_notice.updated_at IS '更新时间（Unix 秒）';
COMMENT ON COLUMN sys_notice.deleted_at IS '软删除标记（Unix 秒），0 表示未删除';

CREATE TABLE IF NOT EXISTS sys_notice_receiver
(
    id         BIGSERIAL PRIMARY KEY,
    notice_id  BIGINT      NOT NULL,
    user_id    BIGINT      NOT NULL,
    read_at    BIGINT NOT NULL DEFAULT 0,
    created_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint),
    updated_at BIGINT NOT NULL DEFAULT (extract(epoch from now())::bigint),
    UNIQUE (notice_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_sys_notice_receiver_user_read
    ON sys_notice_receiver (user_id, read_at);

COMMENT ON TABLE sys_notice_receiver IS '通知接收人表：发布时按范围展开，并记录已读状态';
COMMENT ON COLUMN sys_notice_receiver.id IS '主键';
COMMENT ON COLUMN sys_notice_receiver.notice_id IS '通知 ID，关联 sys_notice.id';
COMMENT ON COLUMN sys_notice_receiver.user_id IS '接收人用户 ID，关联 sys_user.id';
COMMENT ON COLUMN sys_notice_receiver.read_at IS '阅读时间（Unix 秒），0 表示未读';
COMMENT ON COLUMN sys_notice_receiver.created_at IS '投递时间（Unix 秒）';
COMMENT ON COLUMN sys_notice_receiver.updated_at IS '更新时间（Unix 秒）';

-- ---------------------------------------------------------------------------
-- 13. 种子数据
-- ---------------------------------------------------------------------------
-- 默认账号：admin / Admin@123456，首次登录强制改密。
-- 菜单与按钮权限种子在阶段 3/4 实现 RBAC 时补充。

INSERT INTO sys_dept (id, parent_id, ancestors, name, sort, status)
VALUES (1, 0, '{0}', '总部', 1, 1)
ON CONFLICT DO NOTHING;

INSERT INTO sys_role (id, code, name, sort, status)
VALUES (1, 'admin', '超级管理员', 1, 1)
ON CONFLICT DO NOTHING;

INSERT INTO sys_user (id, username, password_hash, nickname, dept_id, status,
                      is_super, must_change_password)
VALUES (1, 'admin',
        '$2a$10$GMu7XmovGjP4veNplguZXurI1rGKGgQxdxmpubMz5vmssC3OWyBYi',
        '超级管理员', 1, 1, TRUE, TRUE)
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
