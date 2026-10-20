/** 后端统一响应体 */
export interface ApiResponse<T = unknown> {
  code: number
  message: string
  data: T
}

/** 分页响应结构 */
export interface PageResult<T> {
  list: T[]
  total: number
  page: number
  pageSize: number
}

/** 业务状态码 */
export const API_CODE = {
  SUCCESS: 10000,
  VALIDATION_ERROR: 40002,
  SESSION_INVALID: 40003,
} as const
