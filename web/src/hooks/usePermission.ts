import { computed } from 'vue'

import { useAccountStore } from '@/stores/account'
import { hasPermission, type PermissionValue } from '@/utils/permission'

/** 组件内权限判断 */
export function usePermission() {
  const account = useAccountStore()

  function hasPerm(required: PermissionValue): boolean {
    return hasPermission(required, account.permissions, account.isSuperAdmin)
  }

  /** 数组入参命中任意一项即可 */
  function hasAnyPerm(required: readonly string[]): boolean {
    return hasPerm(required)
  }

  return {
    hasPerm,
    hasAnyPerm,
    isSuperAdmin: computed(() => account.isSuperAdmin),
  }
}
