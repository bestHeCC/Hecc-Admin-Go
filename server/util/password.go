// Package util 存放无状态纯工具函数。
package util

import (
	"errors"
	"fmt"
	"unicode"

	"golang.org/x/crypto/bcrypt"
)

const bcryptCost = 10

// HashPassword 使用 bcrypt 生成密码哈希。
func HashPassword(plain string) (string, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(plain), bcryptCost)
	if err != nil {
		return "", fmt.Errorf("生成密码哈希失败: %w", err)
	}
	return string(hash), nil
}

// VerifyPassword 校验明文密码与 bcrypt 哈希是否匹配。
func VerifyPassword(hash, plain string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(plain)) == nil
}

// ValidatePassword 校验密码强度：至少 8 位，且同时包含字母与数字。
func ValidatePassword(plain string) error {
	if len(plain) < 8 {
		return errors.New("密码长度不能少于 8 位")
	}

	var hasLetter, hasDigit bool
	for _, r := range plain {
		switch {
		case unicode.IsLetter(r):
			hasLetter = true
		case unicode.IsDigit(r):
			hasDigit = true
		}
	}
	if !hasLetter || !hasDigit {
		return errors.New("密码必须同时包含字母和数字")
	}
	return nil
}
