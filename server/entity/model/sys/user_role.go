package sys

import (
	"github.com/hecc/hecc-admin-go/entity/model"
)

// SysUserRole 用户-角色关联表，对应 sys_user_role。user_id + role_id 唯一。
type SysUserRole struct {
	model.BaseModel

	// UserID 用户 ID，关联 sys_user.id。
	UserID int64 `gorm:"column:user_id;uniqueIndex:ux_sys_user_role_user_role,priority:1" json:"userId"`
	// RoleID 角色 ID，关联 sys_role.id。
	RoleID int64 `gorm:"column:role_id;uniqueIndex:ux_sys_user_role_user_role,priority:2;index" json:"roleId"`
}

// TableName 指定表名。
func (SysUserRole) TableName() string { return "sys_user_role" }
