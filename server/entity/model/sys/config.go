package sys

import (
	"github.com/hecc/hecc-admin-go/entity/model"
)

// SysConfig 系统配置表，对应 sys_config。value 统一按字符串存储，type 指示解析方式
// （string / number / boolean / json）。
type SysConfig struct {
	model.SoftDeleteModel

	// Name 配置名称，供管理端展示。
	Name string `gorm:"column:name" json:"name"`
	// Key 配置键，全局唯一，代码中按此读取。
	Key string `gorm:"column:key" json:"key"`
	// Value 配置值，统一以字符串存储，按 Type 解析。
	Value string `gorm:"column:value" json:"value"`
	// Type 值类型：string / number / boolean / json。
	Type string `gorm:"column:type" json:"type"`
	// Remark 备注。
	Remark string `gorm:"column:remark" json:"remark"`
}

// TableName 指定表名。
func (SysConfig) TableName() string { return "sys_config" }
