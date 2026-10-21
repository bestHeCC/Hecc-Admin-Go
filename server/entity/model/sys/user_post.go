package sys

import (
	"github.com/hecc/hecc-admin-go/entity/model"
)

// SysUserPost 用户-岗位关联表，对应 sys_user_post。user_id + post_id 唯一。
type SysUserPost struct {
	model.BaseModel

	// UserID 用户 ID，关联 sys_user.id。
	UserID int64 `gorm:"column:user_id;uniqueIndex:ux_sys_user_post_user_post,priority:1" json:"userId"`
	// PostID 岗位 ID，关联 sys_post.id。
	PostID int64 `gorm:"column:post_id;uniqueIndex:ux_sys_user_post_user_post,priority:2;index" json:"postId"`
}

// TableName 指定表名。
func (SysUserPost) TableName() string { return "sys_user_post" }
