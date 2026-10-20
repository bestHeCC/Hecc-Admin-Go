import type { Router } from 'vue-router'

import { appConfig } from '@/config'
import { setupDynamicRoutes } from '@/router/dynamic'
import { useAccountStore } from '@/stores/account'
import { useAuthStore } from '@/stores/auth'

/** 注册全局路由守卫 */
export function setupRouterGuards(router: Router): void {
  router.beforeEach(async (to) => {
    const auth = useAuthStore()

    // 未登录：仅放行登录页
    if (!auth.token) {
      if (to.path === appConfig.routes.login) return true
      const query = to.fullPath !== appConfig.routes.home ? { redirect: to.fullPath } : undefined
      return { path: appConfig.routes.login, query }
    }

    // 强制改密期间只允许进入改密页
    if (auth.mustChangePassword) {
      if (to.path === appConfig.routes.changePassword) return true
      return { path: appConfig.routes.changePassword }
    }

    if (to.path === appConfig.routes.login) {
      return { path: appConfig.routes.home }
    }

    const account = useAccountStore()

    // 每个会话首次进入业务页时拉取用户信息与菜单，并注册动态路由
    if (!account.initialized) {
      try {
        await account.load()
        setupDynamicRoutes(router, account.menus)
        return to.fullPath
      } catch {
        auth.clearSession()
        return {
          path: appConfig.routes.login,
          query: to.fullPath !== appConfig.routes.home ? { redirect: to.fullPath } : undefined,
        }
      }
    }

    // 路由级权限兜底
    if (to.meta.permission && !account.hasPermission(to.meta.permission)) {
      return { path: appConfig.routes.forbidden }
    }

    return true
  })

  router.afterEach((to) => {
    document.title = to.meta.title ? `${to.meta.title} - ${appConfig.title}` : appConfig.title
  })
}
