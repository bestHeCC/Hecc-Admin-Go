package sys

import (
	"github.com/hecc/hecc-admin-go/entity/model"
)

// SysMenu 菜单/按钮表，对应 sys_menu。type 取值为 dir / menu / button。
type SysMenu struct {
	model.SoftDeleteModel

	// ParentID 上级菜单 ID，0 表示顶级。
	ParentID int64 `gorm:"column:parent_id;index" json:"parentId"`
	// Name 菜单 / 按钮名称。
	Name string `gorm:"column:name" json:"name"`
	// Type 类型：dir 目录 / menu 菜单 / button 按钮（按钮仅作权限点，无路由）。
	Type string `gorm:"column:type" json:"type"`
	// Path 前端路由路径。
	Path string `gorm:"column:path" json:"path"`
	// Component 前端组件路径，目录类型为空。
	Component string `gorm:"column:component" json:"component"`
	// Permission 权限标识（如 system:user:add），按钮类型必填，用于接口鉴权。
	Permission string `gorm:"column:permission;index" json:"permission"`
	// Icon 菜单图标。
	Icon string `gorm:"column:icon" json:"icon"`
	// Sort 同层级排序值，升序。
	Sort int32 `gorm:"column:sort" json:"sort"`
	// Visible 是否在侧边栏显示，false 表示隐藏但仍可访问。
	Visible bool `gorm:"column:visible" json:"visible"`
	// Status 状态：0 禁用 / 1 启用。
	Status int16 `gorm:"column:status" json:"status"`
}

// TableName 指定表名。
func (SysMenu) TableName() string { return "sys_menu" }
