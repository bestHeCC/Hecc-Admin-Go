package sys

import (
	"github.com/hecc/hecc-admin-go/entity/model"
)

// SysNotice 通知公告表，对应 sys_notice。status 取值为 0 草稿 / 1 已发布。
// DeptID / PostID 来自 model.DataOwner，是发布人所属部门与岗位的快照。
type SysNotice struct {
	model.SoftDeleteModel
	model.DataOwner

	// Title 标题。
	Title string `gorm:"column:title" json:"title"`
	// Content 正文，支持富文本 / Markdown。
	Content string `gorm:"column:content" json:"content"`
	// Type 通知类型：notice 通知 / announcement 公告。
	Type string `gorm:"column:type" json:"type"`
	// TargetType 接收范围：all 全体 / dept 按部门 / user 指定用户。
	TargetType string `gorm:"column:target_type" json:"targetType"`
	// Status 状态：0 草稿 / 1 已发布。
	Status int16 `gorm:"column:status;index:idx_sys_notice_status_published,priority:1" json:"status"`
	// SenderID 发布人用户 ID。
	SenderID int64 `gorm:"column:sender_id" json:"senderId"`
	// PublishedAt 发布时间（Unix 秒），草稿为 0。
	PublishedAt int64 `gorm:"column:published_at;index:idx_sys_notice_status_published,priority:2" json:"publishedAt"`
}

// TableName 指定表名。
func (SysNotice) TableName() string { return "sys_notice" }

// SysNoticeReceiver 通知接收人表，对应 sys_notice_receiver，记录投递与已读状态。
type SysNoticeReceiver struct {
	model.BaseModel

	// NoticeID 通知 ID，关联 sys_notice.id。
	NoticeID int64 `gorm:"column:notice_id;uniqueIndex:ux_sys_notice_receiver_notice_user,priority:1" json:"noticeId"`
	// UserID 接收人用户 ID，关联 sys_user.id。
	UserID int64 `gorm:"column:user_id;uniqueIndex:ux_sys_notice_receiver_notice_user,priority:2;index:idx_sys_notice_receiver_user_read,priority:1" json:"userId"`
	// ReadAt 阅读时间（Unix 秒），0 表示未读。
	ReadAt int64 `gorm:"column:read_at;index:idx_sys_notice_receiver_user_read,priority:2" json:"readAt"`
}

// TableName 指定表名。
func (SysNoticeReceiver) TableName() string { return "sys_notice_receiver" }
