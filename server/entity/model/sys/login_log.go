package sys

import (
	"github.com/hecc/hecc-admin-go/entity/model"
)

// SysLoginLog 登录日志表，对应 sys_login_log。只追加，不更新、不软删除；
// updated_at 与 created_at 相同。
type SysLoginLog struct {
	model.BaseModel

	// Username 尝试登录的登录名，失败时可能不存在对应用户。
	Username string `gorm:"column:username;index" json:"username"`
	// DeptID 用户所属部门快照，用于数据权限过滤。
	DeptID int64 `gorm:"column:dept_id;index" json:"deptId"`
	// PostID 用户所属岗位快照，用于数据权限过滤。
	PostID int64 `gorm:"column:post_id;index" json:"postId"`
	// IP 客户端 IP。
	IP string `gorm:"column:ip" json:"ip"`
	// UA 客户端 User-Agent。
	UA string `gorm:"column:ua" json:"ua"`
	// Status 登录结果：0 失败 / 1 成功。
	Status int16 `gorm:"column:status" json:"status"`
	// Message 结果说明，失败时为错误原因。
	Message string `gorm:"column:message" json:"message"`
}

// TableName 指定表名。
func (SysLoginLog) TableName() string { return "sys_login_log" }
