package enum

// 通用状态值。
const (
	StatusDisabled = 0 // 禁用
	StatusEnabled  = 1 // 启用
)

// 菜单类型。
const (
	MenuTypeDir    = "dir"    // 目录
	MenuTypeMenu   = "menu"   // 页面
	MenuTypeButton = "button" // 按钮（仅权限码）
)

// 通知类型。
const (
	NoticeTypeNotice = "notice" // 通知
	NoticeTypeTodo   = "todo"   // 待办
)

// Redis 键布局。会话认证阶段（阶段 3）统一从这里取键，避免散落硬编码。
const (
	RedisSessionPrefix      = "admin:session:"        // Hash：会话详情
	RedisUserSessionsPrefix = "admin:user:sessions:"  // Set：用户全部会话 hash
	RedisActiveSessionsKey  = "admin:sessions:active" // ZSet：在线会话索引
	RedisContextVersionKey  = "admin:ctx:version"     // String：用户上下文全局版本
	RedisContextPrefix      = "admin:ctx:"            // String：用户上下文缓存
	RedisLoginLimitPrefix   = "admin:limit:login:"    // String：登录限流计数
	RedisHealthProbeKey     = "admin:health:probe"    // String：健康检查探针
)
