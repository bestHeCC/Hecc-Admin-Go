import axios, { type AxiosError, type AxiosRequestConfig } from 'axios'

import { appConfig } from '@/config'
import { API_CODE, type ApiResponse } from '@/models/api'
import { getToken, handleSessionExpired } from '@/utils/auth'

/** 业务异常，保留后端返回的 code */
export class ApiError extends Error {
  readonly code: number

  constructor(message: string, code: number) {
    super(message)
    this.name = 'ApiError'
    this.code = code
  }
}

const service = axios.create({
  baseURL: appConfig.apiBaseUrl,
  timeout: appConfig.apiTimeout,
})

/**
 * 提取用户可见文案。
 * hecc-blot 约定：失败时 `data` 放业务文案，`message` 是通用短语，
 * 因此优先使用 data 中的字符串，数据为空时才回退到 message。
 */
function resolveMessage(body: ApiResponse<unknown>, fallback: string): string {
  if (typeof body.data === 'string' && body.data.trim()) return body.data
  return body.message || fallback
}

// 请求拦截：注入 Bearer Token
service.interceptors.request.use((config) => {
  const token = getToken()
  if (token) {
    config.headers.set('Authorization', `Bearer ${token}`)
  }
  return config
})

// 响应拦截：统一解包 { code, message, data }
service.interceptors.response.use(
  (response) => {
    const body = response.data as ApiResponse<unknown> | undefined
    if (!body || typeof body.code !== 'number') {
      return response.data
    }

    if (body.code === API_CODE.SUCCESS) {
      return body.data
    }

    if (body.code === API_CODE.SESSION_INVALID) {
      handleSessionExpired(body.message || '登录状态已失效，请重新登录')
      return Promise.reject(new ApiError(body.message || '会话已失效', body.code))
    }

    const message = resolveMessage(body, '请求失败，请稍后重试')
    ElMessage.error(message)
    return Promise.reject(new ApiError(message, body.code))
  },
  (error: AxiosError<ApiResponse<unknown>>) => {
    if (axios.isCancel(error)) {
      return Promise.reject(error)
    }

    const body = error.response?.data
    if (error.response?.status === 401 || body?.code === API_CODE.SESSION_INVALID) {
      handleSessionExpired(body?.message || '登录状态已失效，请重新登录')
      return Promise.reject(error)
    }

    const message = body?.message || error.message || '网络异常，请稍后重试'
    ElMessage.error(message)
    return Promise.reject(error)
  },
)

/** 发起请求，拦截器已解包，直接得到业务 data */
export async function request<T = unknown>(config: AxiosRequestConfig): Promise<T> {
  return (await service.request(config)) as unknown as T
}

export default service
