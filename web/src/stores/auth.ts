import { computed, ref } from 'vue'
import { defineStore } from 'pinia'

import type {
  ChangePasswordParams,
  ChangePasswordResult,
  LoginParams,
  LoginResult,
} from '@/models/auth'
import { changePasswordApi, loginApi, logoutApi } from '@/services/auth'
import { useAccountStore } from '@/stores/account'
import {
  clearSessionStorage,
  getMustChangePassword,
  getToken,
  registerSessionClearHandler,
  setMustChangePassword,
  setToken,
} from '@/utils/auth'

/** 会话状态：token / 强制改密 / 登录登出 */
export const useAuthStore = defineStore('auth', () => {
  const token = ref(getToken())
  const mustChangePassword = ref(getMustChangePassword())
  const isLoggedIn = computed(() => Boolean(token.value))

  // 会话失效拦截器不直接依赖 Pinia，这里注册回调同步清理内存状态
  function resetState(): void {
    token.value = ''
    mustChangePassword.value = false
    useAccountStore().reset()
  }

  registerSessionClearHandler(resetState)

  function applySession(nextToken: string, nextMustChangePassword: boolean): void {
    token.value = nextToken
    mustChangePassword.value = nextMustChangePassword
    setToken(nextToken)
    setMustChangePassword(nextMustChangePassword)
  }

  async function login(params: LoginParams): Promise<LoginResult> {
    const result = await loginApi(params)
    applySession(result.token, Boolean(result.mustChangePassword))
    useAccountStore().reset()
    return result
  }

  /** 清理本地会话，不调用后端接口 */
  function clearSession(): void {
    resetState()
    clearSessionStorage()
  }

  async function logout(): Promise<void> {
    try {
      if (token.value) await logoutApi()
    } catch {
      // 登出接口失败不阻塞本地清理
    } finally {
      clearSession()
    }
  }

  async function changePassword(
    params: ChangePasswordParams,
  ): Promise<ChangePasswordResult | null> {
    const result = await changePasswordApi(params)
    if (result?.token) {
      token.value = result.token
      setToken(result.token)
    }
    mustChangePassword.value = false
    setMustChangePassword(false)
    return result
  }

  async function fetchInfo(): Promise<void> {
    await useAccountStore().fetchInfo()
  }

  async function fetchMenus(): Promise<void> {
    await useAccountStore().fetchMenus()
  }

  return {
    token,
    mustChangePassword,
    isLoggedIn,
    login,
    logout,
    clearSession,
    changePassword,
    fetchInfo,
    fetchMenus,
  }
})
