package sys

import (
	"github.com/hecc/hecc-admin-go/entity/model"
)

// SysUser 用户表，对应 sys_user。包含登录凭据与登录风控字段。
type SysUser struct {
	model.SoftDeleteModel

	// Username 登录名，全局唯一（软删除后可复用）。
	Username string `gorm:"column:username" json:"username"`
	// PasswordHash 密码哈希（bcrypt），不存明文，不参与 JSON 序列化。
	PasswordHash string `gorm:"column:password_hash" json:"-"`
	// Nickname 昵称 / 显示名。
	Nickname string `gorm:"column:nickname" json:"nickname"`
	// Email 邮箱。
	Email string `gorm:"column:email" json:"email"`
	// Phone 手机号。
	Phone string `gorm:"column:phone" json:"phone"`
	// Avatar 头像 URL。
	Avatar string `gorm:"column:avatar" json:"avatar"`
	// DeptID 所属部门 ID，0 表示未分配。
	DeptID int64 `gorm:"column:dept_id;index" json:"deptId"`
	// Status 账号状态：0 禁用 / 1 启用（禁用后不可登录）。
	Status int16 `gorm:"column:status" json:"status"`
	// IsSuper 是否超级管理员，为真时跳过权限校验。
	IsSuper bool `gorm:"column:is_super" json:"isSuper"`
	// MustChangePassword 是否强制下次登录修改密码。
	MustChangePassword bool `gorm:"column:must_change_password" json:"mustChangePassword"`
	// BannedUntil 封禁截止时间（Unix 秒），0 表示未封禁。
	BannedUntil int64 `gorm:"column:banned_until" json:"bannedUntil"`
	// BanReason 封禁原因。
	BanReason string `gorm:"column:ban_reason" json:"banReason"`
	// FailedAttempts 连续登录失败次数，登录成功后清零。
	FailedAttempts int32 `gorm:"column:failed_attempts" json:"failedAttempts"`
	// LockedUntil 因失败次数过多触发的临时锁定截止时间（Unix 秒），0 表示未锁定。
	LockedUntil int64 `gorm:"column:locked_until" json:"lockedUntil"`
	// LastLoginAt 最后登录时间（Unix 秒），0 表示从未登录。
	LastLoginAt int64 `gorm:"column:last_login_at" json:"lastLoginAt"`
	// LastLoginIP 最后登录 IP。
	LastLoginIP string `gorm:"column:last_login_ip" json:"lastLoginIp"`
	// Remark 备注。
	Remark string `gorm:"column:remark" json:"remark"`
}

// TableName 指定表名。
func (SysUser) TableName() string { return "sys_user" }
