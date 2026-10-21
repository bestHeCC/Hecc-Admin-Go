package sys

import (
	"github.com/hecc/hecc-admin-go/entity/model"
)

// SysDept 部门表，对应 sys_dept。parent_id = 0 表示顶级，ancestors 保存祖级链路。
type SysDept struct {
	model.SoftDeleteModel

	// ParentID 上级部门 ID，0 表示顶级部门。
	ParentID int64 `gorm:"column:parent_id;index" json:"parentId"`
	// Ancestors 祖级链路（含根 0、不含自身），如 {0,1,3}，
	// 用 ancestors @> ARRAY[?] 查询子孙部门，配合 GIN 索引。
	Ancestors model.Array[int64] `gorm:"column:ancestors;type:bigint[]" json:"ancestors"`
	// Name 部门名称。
	Name string `gorm:"column:name" json:"name"`
	// LeaderID 负责人用户 ID，关联 sys_user.id；0 表示未关联或无系统账号。
	LeaderID int64 `gorm:"column:leader_id;index" json:"leaderId"`
	// Leader 负责人姓名（展示快照，不随用户改名自动变化）。
	Leader string `gorm:"column:leader" json:"leader"`
	// Phone 部门联系电话（非负责人个人手机号）。
	Phone string `gorm:"column:phone" json:"phone"`
	// Email 部门邮箱（非负责人个人邮箱）。
	Email string `gorm:"column:email" json:"email"`
	// Sort 同层级排序值，升序。
	Sort int32 `gorm:"column:sort" json:"sort"`
	// Status 状态：0 禁用 / 1 启用。
	Status int16 `gorm:"column:status" json:"status"`
}

// TableName 指定表名。
func (SysDept) TableName() string { return "sys_dept" }
