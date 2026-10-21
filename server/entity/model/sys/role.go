package sys

import (
	"github.com/hecc/hecc-admin-go/entity/model"
)

// SysRole 角色表，对应 sys_role。code 在未删除记录中唯一。
type SysRole struct {
	model.SoftDeleteModel

	// Code 角色编码（如 admin），全局唯一，代码中按此判断。
	Code string `gorm:"column:code" json:"code"`
	// Name 角色名称。
	Name string `gorm:"column:name" json:"name"`
	// Sort 排序值，升序。
	Sort int32 `gorm:"column:sort" json:"sort"`
	// Status 状态：0 禁用 / 1 启用。
	Status int16 `gorm:"column:status" json:"status"`
	// Remark 备注。
	Remark string `gorm:"column:remark" json:"remark"`
}

// TableName 指定表名。
func (SysRole) TableName() string { return "sys_role" }
