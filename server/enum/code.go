// Package enum 存放业务码、状态值与 Redis 键等常量。
package enum

import "github.com/hecc-blot/framework/enum/response"

// Code 是统一响应码。框架协议码 10000/40000/50000 段与业务扩展码 60000+ 段共用同一类型。
type Code = response.Value

const (
	// 框架协议码（与 hecc-blot framework/enum/response 保持一致）。
	CodeSuccess          Code = response.Success          // 10000
	CodeFail             Code = response.Fail             // 40000
	CodeBusy             Code = response.Busy             // 40001
	CodeValidateError    Code = response.ValidateError    // 40002
	CodeTokenInvalid     Code = response.TokenInvalid     // 40003
	CodeAccessDenied     Code = response.AccessDenied     // 40004
	CodeNoDataPermission Code = response.NoDataPermission // 40005
	CodeRateLimit        Code = response.RateLimit        // 40006
	CodeIllegal          Code = response.Illegal          // 50000
	CodePanic            Code = response.Panic            // 50001
)

// 业务扩展码：60000+。框架查不到这些码的通用文案，
// 因此 Call 返回错误时必须通过 errorSvc.New(code, "用户可见文案") 附带文案。
const (
	CodePasswordChangeRequired Code = 60010 // 必须先修改密码
	CodeAccountDisabled        Code = 60011 // 账号已禁用
	CodeAccountLocked          Code = 60012 // 账号已锁定
	CodeAccountBanned          Code = 60013 // 账号已被封禁
	CodeInvalidCredentials     Code = 60020 // 用户名或密码错误
	CodeUserNotFound           Code = 60021 // 用户不存在
	CodeSessionNotFound        Code = 60022 // 会话不存在或已失效
)
