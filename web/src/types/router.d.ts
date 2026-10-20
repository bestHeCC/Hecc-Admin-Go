import 'vue-router'

declare module 'vue-router' {
  interface RouteMeta {
    /** 页面标题 */
    title?: string
    /** 菜单图标（Element Plus 图标名） */
    icon?: string
    /** 页面权限码 */
    permission?: string
    /** 是否允许未登录访问 */
    public?: boolean
    /** 是否在菜单中隐藏 */
    hidden?: boolean
    /** 对应后端菜单 ID */
    menuId?: number | string
  }
}

export {}
