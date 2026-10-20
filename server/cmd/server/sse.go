package main

// SSE 端点将在阶段 5 接入：
//
//	sseHandle := sse.NewSseSvc(apiHandle, container)
//	sseHandle.Get("admin/notice/stream", &noticeSse.NoticeSse{})
//
// 认证信息由 SessionMiddleware 写入 Request.Context，
// NoticeSse.Serve 再从 ctx 中读取用户与会话信息。
