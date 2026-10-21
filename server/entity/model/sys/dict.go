package sys

import (
	"github.com/hecc/hecc-admin-go/entity/model"
)

// SysDictType 字典类型表，对应 sys_dict_type。type 在未删除记录中唯一。
type SysDictType struct {
	model.SoftDeleteModel

	// Name 字典名称，供管理端展示。
	Name string `gorm:"column:name" json:"name"`
	// Type 字典类型编码，全局唯一，sys_dict_item.type_code 引用此值。
	Type string `gorm:"column:type" json:"type"`
	// Status 状态：0 禁用 / 1 启用。
	Status int16 `gorm:"column:status" json:"status"`
	// Remark 备注。
	Remark string `gorm:"column:remark" json:"remark"`
}

// TableName 指定表名。
func (SysDictType) TableName() string { return "sys_dict_type" }

// SysDictItem 字典项表，对应 sys_dict_item。type_code 逻辑关联 sys_dict_type.type。
type SysDictItem struct {
	model.SoftDeleteModel

	// TypeCode 所属字典类型编码，逻辑关联 sys_dict_type.type（不建外键）。
	TypeCode string `gorm:"column:type_code;index" json:"typeCode"`
	// Label 展示文案。
	Label string `gorm:"column:label" json:"label"`
	// Value 实际存储值，同一类型下唯一。
	Value string `gorm:"column:value" json:"value"`
	// Sort 同类型内排序值，升序。
	Sort int32 `gorm:"column:sort" json:"sort"`
	// TagType 前端标签样式（如 success / warning / danger），空表示普通文本。
	TagType string `gorm:"column:tag_type" json:"tagType"`
	// Status 状态：0 禁用 / 1 启用。
	Status int16 `gorm:"column:status" json:"status"`
	// Remark 备注。
	Remark string `gorm:"column:remark" json:"remark"`
}

// TableName 指定表名。
func (SysDictItem) TableName() string { return "sys_dict_item" }
