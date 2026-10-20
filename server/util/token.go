package util

import (
	"crypto/rand"
	"encoding/base64"
	"fmt"
)

// DefaultTokenBytes 会话 token 的默认随机字节数。
const DefaultTokenBytes = 32

// RandomToken 生成 URL 安全的随机 token。
//
// 返回的是明文 token；服务端存储时应先做 SHA-256，只保存哈希。
func RandomToken(n int) (string, error) {
	if n <= 0 {
		n = DefaultTokenBytes
	}
	buf := make([]byte, n)
	if _, err := rand.Read(buf); err != nil {
		return "", fmt.Errorf("生成随机 token 失败: %w", err)
	}
	return base64.RawURLEncoding.EncodeToString(buf), nil
}
