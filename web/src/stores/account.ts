import { computed, ref } from 'vue'
import { defineStore } from 'pinia'

import type { UserInfo } from '@/models/auth'
import type { MenuItem } from '@/models/menu'
import { getInfoApi, getMenusApi } from '@/services/auth'
import { hasPermission as checkPermission, type PermissionValue } from '@/utils/permission'

function unique(values: string[]): string[] {
  return [...new Set(values.filter(Boolean))]
}

function isSuperRole(role: string): boolean {
  return ['superadmin', 'super_admin', 'super-admin'].includes(role.toLowerCase())
}

/** 账号资料、权限与菜单状态 */
export const useAccountStore = defineStore('account', () => {
  const user = ref<UserInfo | null>(null)
  const roles = ref<string[]>([])
  const permissions = ref<string[]>([])
  const menus = ref<MenuItem[]>([])
  const initialized = ref(false)
  const loading = ref(false)

  const isSuperAdmin = computed(() => {
    return (
      user.value?.isSuperAdmin === true ||
      roles.value.some((role) => isSuperRole(role)) ||
      permissions.value.includes('*')
    )
  })

  let loadingPromise: Promise<void> | null = null

  async function fetchInfo(): Promise<void> {
    const data = await getInfoApi()
    const profile: UserInfo = data.user ?? data
    user.value = profile
    roles.value = unique([...(data.roles ?? []), ...(profile.roles ?? [])])
    permissions.value = unique([...(data.permissions ?? []), ...(profile.permissions ?? [])])
  }

  async function fetchMenus(): Promise<void> {
    const result = await getMenusApi()
    menus.value = Array.isArray(result) ? result : []
  }

  /** 拉取账号信息与菜单，同一会话只请求一次 */
  async function load(force = false): Promise<void> {
    if (initialized.value && !force) return
    if (loadingPromise) return loadingPromise

    loading.value = true
    loadingPromise = (async () => {
      try {
        await Promise.all([fetchInfo(), fetchMenus()])
        initialized.value = true
      } finally {
        loading.value = false
        loadingPromise = null
      }
    })()

    return loadingPromise
  }

  function hasPermission(required: PermissionValue): boolean {
    return checkPermission(required, permissions.value, isSuperAdmin.value)
  }

  function reset(): void {
    user.value = null
    roles.value = []
    permissions.value = []
    menus.value = []
    initialized.value = false
    loading.value = false
    loadingPromise = null
  }

  return {
    user,
    roles,
    permissions,
    menus,
    initialized,
    loading,
    isSuperAdmin,
    fetchInfo,
    fetchMenus,
    load,
    hasPermission,
    reset,
  }
})
