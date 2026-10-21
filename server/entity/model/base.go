// Package model 存放跨模块复用的 GORM 模型基类，业务模型按模块放在子包中。
//
// 业务模型组合 BaseModel/SoftDeleteModel 与 DataOwner：
//
//	type SysNotice struct {
//	    model.SoftDeleteModel
//	    model.DataOwner
//	    Title string `gorm:"column:title"`
//	}
//
//	func (SysNotice) TableName() string { return "sys_notice" }
//
// 时间字段统一为 Unix 秒（int64）。created_at / updated_at 由 GORM 自动填充，
// deleted_at 使用 soft_delete 插件：0 表示未删除，删除时写入当前 Unix 秒。
package model

import "gorm.io/plugin/soft_delete"

// BaseModel 是模型的公共字段。GetID 满足 hecc-blot db 的 IDbModel 契约。
type BaseModel struct {
	ID        int64 `gorm:"column:id;primaryKey;autoIncrement" json:"id"`
	CreatedAt int64 `gorm:"column:created_at;autoCreateTime" json:"createdAt"`
	UpdatedAt int64 `gorm:"column:updated_at;autoUpdateTime" json:"updatedAt"`
}

// GetID 实现 dbContract.IDbModel。
func (m BaseModel) GetID() int { return int(m.ID) }

// SoftDeleteModel 在 BaseModel 之上增加软删除字段，0 表示未删除。
type SoftDeleteModel struct {
	BaseModel
	DeletedAt soft_delete.DeletedAt `gorm:"column:deleted_at;index;softDelete:unix" json:"-"`
}

// DataOwner 标识业务数据的归属，用于数据权限过滤。
//
// 未设置部门与岗位的记录（两字段均为 0）视为全局数据，对所有有模块权限的用户可见。
type DataOwner struct {
	DeptID int64 `gorm:"column:dept_id;index" json:"deptId"`
	PostID int64 `gorm:"column:post_id;index" json:"postId"`
}
