import { appConfig } from '@/config'
import { getStorage, removeStorage, setStorage } from '@/utils/storage'

const { storageKeys, routes } = appConfig

let redirectTimer: ReturnType<typeof setTimeout> | null = null
let lastSessionMessageAt = 0
let sessionClearHandler: (() => void) | null = null

/** 由 auth store 注册，会话失效时同步清空内存中的登录态 */
export function registerSessionClearHandler(handler: () => void): void {
  sessionClearHandler = handler
}

export function getToken(): string {
  return getStorage<string>(storageKeys.token) ?? ''
}

export function setToken(token: string): void {
  if (token) {
    setStorage(storageKeys.token, token)
  } else {
    removeStorage(storageKeys.token)
  }
}

export function getMustChangePassword(): boolean {
  return getStorage<boolean>(storageKeys.mustChangePassword) ?? false
}

export function setMustChangePassword(value: boolean): void {
  setStorage(storageKeys.mustChangePassword, value)
}

/** 清理本地会话数据（token 与强制改密标记） */
export function clearSessionStorage(): void {
  removeStorage(storageKeys.token)
  removeStorage(storageKeys.mustChangePassword)
}

/**
 * 会话失效统一处理：无 refresh 流程，清理会话并跳转登录页。
 * 通过定时器与时间戳去重，避免并发请求触发多次提示和重复跳转。
 */
export function handleSessionExpired(message = '登录状态已失效，请重新登录'): void {
  clearSessionStorage()
  sessionClearHandler?.()

  const now = Date.now()
  if (now - lastSessionMessageAt > 1500) {
    lastSessionMessageAt = now
    ElMessage.warning({ message, duration: 1500 })
  }

  if (window.location.pathname === routes.login) return
  if (redirectTimer) return

  const current = `${window.location.pathname}${window.location.search}${window.location.hash}`
  redirectTimer = setTimeout(() => {
    redirectTimer = null
    if (window.location.pathname === routes.login) return

    const query =
      current && current !== routes.home ? `?redirect=${encodeURIComponent(current)}` : ''
    window.location.replace(`${routes.login}${query}`)
  }, 600)
}
