// Package model 存放 GORM 模型，表名统一使用 sys_ 前缀。
//
// 业务模型组合 BaseModel/SoftDeleteModel 与 DataOwner：
//
//	type SysNotice struct {
//	    model.BaseModel
//	    model.DataOwner
//	    Title string `gorm:"column:title"`
//	}
//
//	func (SysNotice) TableName() string { return "sys_notice" }
package model

import (
	"time"

	"gorm.io/gorm"
)

// BaseModel 是模型的公共字段。GetID 满足 hecc-blot db 的 IDbModel 契约。
type BaseModel struct {
	ID        int64     `gorm:"column:id;primaryKey;autoIncrement" json:"id"`
	CreatedAt time.Time `gorm:"column:created_at;autoCreateTime" json:"createdAt"`
	UpdatedAt time.Time `gorm:"column:updated_at;autoUpdateTime" json:"updatedAt"`
}

// GetID 实现 dbContract.IDbModel。
func (m BaseModel) GetID() int { return int(m.ID) }

// SoftDeleteModel 在 BaseModel 之上增加软删除字段。
type SoftDeleteModel struct {
	BaseModel
	DeletedAt gorm.DeletedAt `gorm:"column:deleted_at;index" json:"-"`
}

// DataOwner 标识业务数据的归属，用于数据权限过滤。
//
// 未设置部门与岗位的记录（两字段均为 0）视为全局数据，对所有有模块权限的用户可见。
type DataOwner struct {
	DeptID int64 `gorm:"column:dept_id;index" json:"deptId"`
	PostID int64 `gorm:"column:post_id;index" json:"postId"`
}
