/** 登录请求 */
export interface LoginParams {
  username: string
  password: string
}

/** 登录响应 */
export interface LoginResult {
  token: string
  mustChangePassword: boolean
}

/** 用户基础信息 */
export interface UserInfo {
  id?: number | string
  username?: string
  nickname?: string
  avatar?: string
  email?: string
  phone?: string
  deptName?: string
  roles?: string[]
  permissions?: string[]
  isSuperAdmin?: boolean
}

/** 用户信息接口兼容直接返回或 { user, roles, permissions } 两种结构 */
export interface AuthInfoResponse extends UserInfo {
  user?: UserInfo
  permissions?: string[]
  roles?: string[]
}

/** 修改密码请求 */
export interface ChangePasswordParams {
  oldPassword: string
  newPassword: string
}

/** 修改密码响应，部分实现会返回新 token */
export interface ChangePasswordResult {
  token?: string
}
