package util

import "testing"

func TestHashAndVerifyPassword(t *testing.T) {
	const plain = "Admin@123456"

	hash, err := HashPassword(plain)
	if err != nil {
		t.Fatalf("HashPassword() error = %v", err)
	}
	if hash == plain {
		t.Fatal("哈希结果不应等于明文")
	}
	if !VerifyPassword(hash, plain) {
		t.Fatal("正确密码应校验通过")
	}
	if VerifyPassword(hash, "wrong-password") {
		t.Fatal("错误密码不应校验通过")
	}
}

func TestValidatePassword(t *testing.T) {
	cases := []struct {
		name    string
		plain   string
		wantErr bool
	}{
		{name: "合法", plain: "Admin@123", wantErr: false},
		{name: "过短", plain: "Ab1", wantErr: true},
		{name: "缺少数字", plain: "abcdefgh", wantErr: true},
		{name: "缺少字母", plain: "12345678", wantErr: true},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if err := ValidatePassword(tc.plain); (err != nil) != tc.wantErr {
				t.Fatalf("ValidatePassword(%q) error = %v, wantErr = %v", tc.plain, err, tc.wantErr)
			}
		})
	}
}
