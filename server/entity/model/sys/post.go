package sys

import (
	"github.com/hecc/hecc-admin-go/entity/model"
)

// SysPost 岗位表，对应 sys_post。code 在未删除记录中唯一。
type SysPost struct {
	model.SoftDeleteModel

	// Code 岗位编码，全局唯一（软删除后可复用）。
	Code string `gorm:"column:code" json:"code"`
	// Name 岗位名称。
	Name string `gorm:"column:name" json:"name"`
	// Sort 排序值，升序。
	Sort int32 `gorm:"column:sort" json:"sort"`
	// Status 状态：0 禁用 / 1 启用。
	Status int16 `gorm:"column:status" json:"status"`
	// Remark 备注。
	Remark string `gorm:"column:remark" json:"remark"`
}

// TableName 指定表名。
func (SysPost) TableName() string { return "sys_post" }
