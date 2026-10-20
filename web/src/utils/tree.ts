import type { MenuItem } from '@/models/menu'

/** 是否为外部链接 */
export function isExternalPath(path: string): boolean {
  return /^(https?:)?\/\//.test(path) || path.startsWith('mailto:')
}

function normalizeSlashes(path: string): string {
  const normalized = path.replace(/\/+/g, '/').replace(/\/+$/, '')
  return normalized.startsWith('/') ? normalized : `/${normalized}`
}

/** 拼接菜单路径，子菜单相对路径会基于父路径补全 */
export function resolveMenuPath(parentPath: string, path?: string | null): string {
  if (!path) return ''
  if (isExternalPath(path)) return path
  if (path.startsWith('/')) return normalizeSlashes(path)

  const parent = parentPath.replace(/\/+$/, '')
  return normalizeSlashes(`${parent}/${path}`)
}

/** 在菜单树中查找当前路径对应的完整链路（用于面包屑） */
export function findMenuPath(menus: MenuItem[], targetPath: string, parentPath = ''): MenuItem[] {
  for (const menu of menus) {
    const fullPath = resolveMenuPath(parentPath, menu.path)
    if (!fullPath || isExternalPath(fullPath)) continue

    if (fullPath === targetPath) return [menu]

    if (menu.children?.length && targetPath.startsWith(`${fullPath}/`)) {
      const childPath = findMenuPath(menu.children, targetPath, fullPath)
      if (childPath.length > 0) return [menu, ...childPath]
    }
  }
  return []
}
