import type { Directive } from 'vue'

import { useAccountStore } from '@/stores/account'
import { hasPermission, type PermissionValue } from '@/utils/permission'

const originalDisplay = new WeakMap<HTMLElement, string>()

function updateVisibility(el: HTMLElement, value: PermissionValue): void {
  if (!originalDisplay.has(el)) {
    originalDisplay.set(el, el.style.display)
  }

  const account = useAccountStore()
  const allowed = hasPermission(value, account.permissions, account.isSuperAdmin)
  el.style.display = allowed ? (originalDisplay.get(el) ?? '') : 'none'
}

/** v-hasPerm：缺少权限时隐藏元素，超级管理员与通配权限直接放行 */
export const hasPermDirective: Directive<HTMLElement, PermissionValue> = {
  mounted(el, binding) {
    updateVisibility(el, binding.value)
  },
  updated(el, binding) {
    updateVisibility(el, binding.value)
  },
}

export default hasPermDirective
