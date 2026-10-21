package sys

import (
	"github.com/hecc/hecc-admin-go/entity/model"
)

// SysRoleMenu 角色-菜单关联表，对应 sys_role_menu。role_id + menu_id 唯一。
type SysRoleMenu struct {
	model.BaseModel

	// RoleID 角色 ID，关联 sys_role.id。
	RoleID int64 `gorm:"column:role_id;uniqueIndex:ux_sys_role_menu_role_menu,priority:1" json:"roleId"`
	// MenuID 菜单 / 按钮 ID，关联 sys_menu.id。
	MenuID int64 `gorm:"column:menu_id;uniqueIndex:ux_sys_role_menu_role_menu,priority:2;index" json:"menuId"`
}

// TableName 指定表名。
func (SysRoleMenu) TableName() string { return "sys_role_menu" }
