import { defineComponent, h, type Component } from 'vue'
import { RouterView, type RouteRecordRaw, type Router } from 'vue-router'

import { appConfig } from '@/config'
import type { MenuItem } from '@/models/menu'
import { DEFAULT_LAYOUT_NAME } from '@/router/index'
import { isExternalPath, resolveMenuPath } from '@/utils/tree'

/** 所有视图的懒加载映射，供后端 component 字符串匹配 */
const viewModules = import.meta.glob<Component>('../views/**/*.vue')

const NotFound = () => import('@/views/error/NotFoundView.vue')

/** 无页面组件的目录菜单使用此容器承载子路由 */
const RouteContainer = defineComponent({
  name: 'RouteContainer',
  render: () => h(RouterView),
})

let removeDynamicRoutes: Array<() => void> = []
let removeCatchAllRoute: (() => void) | null = null

function normalizeComponentPath(component: string): string {
  return component
    .trim()
    .replace(/^@\//, '')
    .replace(/^src\//, '')
    .replace(/^views\//, '')
    .replace(/^\/+/, '')
    .replace(/\.vue$/, '')
}

/** 将后端 component 字符串映射为 views 下的懒加载组件 */
function resolveView(component?: string | null): RouteRecordRaw['component'] | null {
  if (!component) return null

  const normalized = normalizeComponentPath(component)
  const candidates = [`../views/${normalized}.vue`, `../views/${normalized}/index.vue`]

  for (const candidate of candidates) {
    const view = viewModules[candidate]
    if (view) return view
  }

  console.warn(`[router] 未找到菜单组件：${component}`)
  return null
}

function routeName(menu: MenuItem, fullPath: string): string {
  const raw = menu.id ?? fullPath
  return `menu-${String(raw).replace(/[^\w-]/g, '-')}`
}

function buildMenuRoutes(menu: MenuItem, parentPath = ''): RouteRecordRaw[] {
  const fullPath = resolveMenuPath(parentPath, menu.path)
  if (fullPath && isExternalPath(fullPath)) return []

  const children = (menu.children ?? []).flatMap((child) =>
    buildMenuRoutes(child, fullPath || parentPath),
  )

  // 无路径的分组菜单直接展开子路由
  if (!fullPath) return children

  // 有子菜单但组件缺失/无法解析时，用 RouterView 容器承载子路由
  const view = resolveView(menu.component)
  const route = {
    path: fullPath,
    name: routeName(menu, fullPath),
    component: view ?? (children.length > 0 ? RouteContainer : NotFound),
    meta: {
      title: menu.name,
      icon: menu.icon ?? undefined,
      permission: menu.permission ?? undefined,
      menuId: menu.id,
      hidden: menu.visible === false,
    },
    ...(children.length > 0 ? { children } : {}),
  } as RouteRecordRaw

  return [route]
}

/** 清理旧动态路由与 404 兜底 */
export function resetDynamicRoutes(router: Router): void {
  removeDynamicRoutes.forEach((remove) => remove())
  removeDynamicRoutes = []
  removeCatchAllRoute?.()
  removeCatchAllRoute = null

  if (router.hasRoute('CatchAll')) {
    router.removeRoute('CatchAll')
  }
}

/** 将后端菜单树挂载到 DefaultLayout 下，最后追加 404 兜底 */
export function setupDynamicRoutes(router: Router, menus: MenuItem[]): void {
  resetDynamicRoutes(router)

  menus.forEach((menu) => {
    buildMenuRoutes(menu).forEach((route) => {
      removeDynamicRoutes.push(router.addRoute(DEFAULT_LAYOUT_NAME, route))
    })
  })

  removeCatchAllRoute = router.addRoute({
    path: '/:pathMatch(.*)*',
    name: 'CatchAll',
    redirect: appConfig.routes.notFound,
    meta: { public: true, hidden: true },
  })
}
