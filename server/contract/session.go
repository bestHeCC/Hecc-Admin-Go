package contract

import (
	"context"
	"time"
)

// Session 描述一条服务端会话。
//
// 认证不采用 JWT：登录后生成随机 token，Redis 中只保存 token 的 SHA-256，
// 删除会话即等于吊销该 token。具体实现见阶段 3（service/session）。
type Session struct {
	SessionID        string    `json:"sessionId"`
	UserID           int64     `json:"userId"`
	Username         string    `json:"username"`
	LoginIP          string    `json:"loginIp"`
	UserAgent        string    `json:"userAgent"`
	LoginAt          time.Time `json:"loginAt"`
	LastActiveAt     time.Time `json:"lastActiveAt"`
	AbsoluteExpireAt time.Time `json:"absoluteExpireAt"`
}

// ISessionStore 是会话存储的抽象。
//
// 约定：
//   - Create 返回明文 token，仅此一次暴露给客户端，存储层只保留其哈希；
//   - Get/Delete 接收明文 token，内部自行哈希后查 Redis；
//   - Touch 用于滑动续期并刷新在线会话索引；
//   - DeleteByUser 用于封禁、改密、管理员踢出全部会话。
type ISessionStore interface {
	Create(ctx context.Context, session *Session, idleTTL time.Duration) (token string, err error)
	Get(ctx context.Context, token string) (*Session, error)
	Touch(ctx context.Context, token string, idleTTL time.Duration) error
	Delete(ctx context.Context, token string) error
	DeleteByUser(ctx context.Context, userID int64) error
	ListByUser(ctx context.Context, userID int64) ([]*Session, error)
}
