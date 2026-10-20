package util

import "testing"

func TestRandomToken(t *testing.T) {
	a, err := RandomToken(32)
	if err != nil {
		t.Fatalf("RandomToken() error = %v", err)
	}
	b, err := RandomToken(32)
	if err != nil {
		t.Fatalf("RandomToken() error = %v", err)
	}

	if a == "" || b == "" {
		t.Fatal("token 不应为空")
	}
	if a == b {
		t.Fatal("连续生成的 token 不应相同")
	}
	// 32 字节经 base64url（无填充）编码后长度为 43。
	if len(a) != 43 {
		t.Fatalf("token 长度 = %d, want 43", len(a))
	}
}
