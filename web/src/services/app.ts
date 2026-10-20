import { request } from '@/utils/request'

export interface HealthResult {
  status: string
}

/** 服务健康检查 */
export function getHealthApi(): Promise<HealthResult> {
  return request<HealthResult>({
    url: '/health',
    method: 'get',
  })
}

/** 当前用户未读通知数 */
export function getUnreadCountApi(): Promise<number> {
  return request<number>({
    url: '/admin/notice/mine/unread-count',
    method: 'get',
  })
}
