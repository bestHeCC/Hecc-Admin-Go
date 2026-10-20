// Package api 存放 API 请求/响应 DTO。
//
// 命名约定（自动 CRUD 依赖）：
//   - XxxPageReq 实现 Paging() 与 Build()；
//   - XxxCreateReq 实现 ToModel()；
//   - XxxUpdateReq 实现 GetID() 与 Apply(existing)。
package api

const (
	DefaultPage     = 1
	DefaultPageSize = 10
	MaxPageSize     = 100
)

// IDRequest 是通用的按 ID 查询/删除请求。
type IDRequest struct {
	ID int64 `json:"id" form:"id" binding:"required"`
}

// PageRequest 是通用分页请求，业务 DTO 通过匿名嵌入复用它。
type PageRequest struct {
	Page     int `json:"page" form:"page"`
	PageSize int `json:"pageSize" form:"pageSize"`
}

// Paging 返回规范化后的页码与每页条数。
func (r PageRequest) Paging() (page, size int) {
	page, size = r.Page, r.PageSize
	if page <= 0 {
		page = DefaultPage
	}
	if size <= 0 {
		size = DefaultPageSize
	}
	if size > MaxPageSize {
		size = MaxPageSize
	}
	return page, size
}
