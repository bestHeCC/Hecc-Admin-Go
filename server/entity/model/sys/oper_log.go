package sys

import (
	"github.com/hecc/hecc-admin-go/entity/model"
)

// SysOperLog 操作日志表，对应 sys_oper_log。只追加，不更新、不软删除；
// updated_at 与 created_at 相同。
type SysOperLog struct {
	model.BaseModel

	// UserID 操作人用户 ID，0 表示未登录 / 匿名。
	UserID int64 `gorm:"column:user_id;index" json:"userId"`
	// Username 操作人登录名快照。
	Username string `gorm:"column:username" json:"username"`
	// DeptID 操作人所属部门快照，用于数据权限过滤。
	DeptID int64 `gorm:"column:dept_id;index" json:"deptId"`
	// PostID 操作人所属岗位快照，用于数据权限过滤。
	PostID int64 `gorm:"column:post_id;index" json:"postId"`
	// Module 业务模块（如 用户管理）。
	Module string `gorm:"column:module" json:"module"`
	// Action 操作类型（如 新增 / 修改 / 删除）。
	Action string `gorm:"column:action" json:"action"`
	// Method HTTP 方法。
	Method string `gorm:"column:method" json:"method"`
	// Path 请求路径。
	Path string `gorm:"column:path" json:"path"`
	// IP 客户端 IP。
	IP string `gorm:"column:ip" json:"ip"`
	// UA 客户端 User-Agent。
	UA string `gorm:"column:ua" json:"ua"`
	// Code 响应业务码，0 表示成功。
	Code int32 `gorm:"column:code" json:"code"`
	// DurationMS 处理耗时，毫秒。
	DurationMS int64 `gorm:"column:duration_ms" json:"durationMs"`
}

// TableName 指定表名。
func (SysOperLog) TableName() string { return "sys_oper_log" }
