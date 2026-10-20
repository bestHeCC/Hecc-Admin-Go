export type PermissionValue = string | readonly string[] | null | undefined

/** 判断权限码是否匹配，支持 *、*:*:* 与 system:* 通配 */
function matchPermission(granted: string, required: string): boolean {
  if (granted === required || granted === '*' || granted === '*:*:*') return true
  if (granted.endsWith(':*')) {
    const prefix = granted.slice(0, -1)
    return required.startsWith(prefix)
  }
  return false
}

/**
 * 判断是否拥有指定权限。
 * 数组入参默认为“任一权限满足”即可；超级管理员或 * 权限直接放行。
 */
export function hasPermission(
  required: PermissionValue,
  granted: readonly string[],
  isSuperAdmin = false,
): boolean {
  if (isSuperAdmin) return true
  if (!required) return true

  const requiredList = (Array.isArray(required) ? required : [required]).filter(Boolean)
  if (requiredList.length === 0) return true

  return requiredList.some((item) => granted.some((owned) => matchPermission(owned, item)))
}
