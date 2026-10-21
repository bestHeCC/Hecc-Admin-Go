package sys

import (
	"github.com/hecc/hecc-admin-go/entity/model"
)

// SysFile 文件表，对应 sys_file。文件内容存于本地或对象存储，这里只保存元信息。
// DeptID / PostID 来自 model.DataOwner，是上传人所属部门与岗位的快照。
type SysFile struct {
	model.SoftDeleteModel
	model.DataOwner

	// OriginalName 原始文件名，供下载时还原。
	OriginalName string `gorm:"column:original_name" json:"originalName"`
	// ObjectKey 存储对象键 / 相对路径，定位实际文件。
	ObjectKey string `gorm:"column:object_key" json:"objectKey"`
	// URL 对外访问 URL。
	URL string `gorm:"column:url" json:"url"`
	// Size 文件大小，字节。
	Size int64 `gorm:"column:size" json:"size"`
	// MIME MIME 类型。
	MIME string `gorm:"column:mime" json:"mime"`
	// Storage 存储位置：local 本地 / oss 对象存储。
	Storage string `gorm:"column:storage" json:"storage"`
	// UploaderID 上传人用户 ID。
	UploaderID int64 `gorm:"column:uploader_id;index" json:"uploaderId"`
}

// TableName 指定表名。
func (SysFile) TableName() string { return "sys_file" }
