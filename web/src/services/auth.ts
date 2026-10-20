import type {
  AuthInfoResponse,
  ChangePasswordParams,
  ChangePasswordResult,
  LoginParams,
  LoginResult,
} from '@/models/auth'
import type { MenuItem } from '@/models/menu'
import { request } from '@/utils/request'

/** 登录 */
export function loginApi(data: LoginParams): Promise<LoginResult> {
  return request<LoginResult>({
    url: '/admin/auth/login',
    method: 'post',
    data,
  })
}

/** 退出登录 */
export function logoutApi(): Promise<unknown> {
  return request({
    url: '/admin/auth/logout',
    method: 'post',
  })
}

/** 当前用户信息 */
export function getInfoApi(): Promise<AuthInfoResponse> {
  return request<AuthInfoResponse>({
    url: '/admin/auth/info',
    method: 'get',
  })
}

/** 当前用户菜单树 */
export function getMenusApi(): Promise<MenuItem[]> {
  return request<MenuItem[]>({
    url: '/admin/auth/menus',
    method: 'get',
  })
}

/** 修改密码 */
export function changePasswordApi(
  data: ChangePasswordParams,
): Promise<ChangePasswordResult | null> {
  return request<ChangePasswordResult | null>({
    url: '/admin/auth/password',
    method: 'post',
    data,
  })
}
