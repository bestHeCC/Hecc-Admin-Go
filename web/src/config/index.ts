const apiBaseUrl = (import.meta.env.VITE_API_BASE_URL || '/api').replace(/\/+$/, '')
const apiTimeout = Number(import.meta.env.VITE_API_TIMEOUT)
const timeout = Number.isFinite(apiTimeout) && apiTimeout > 0 ? apiTimeout : 15_000

/** 应用级配置 */
export const appConfig = {
  title: import.meta.env.VITE_APP_TITLE || 'Hecc Admin',
  apiBaseUrl,
  apiTimeout: timeout,
  noticeStreamUrl: `${apiBaseUrl}/admin/notice/stream`,
  storageKeys: {
    token: 'hecc_admin_token',
    mustChangePassword: 'hecc_admin_must_change_password',
    sidebarCollapsed: 'hecc_admin_sidebar_collapsed',
  },
  routes: {
    home: '/',
    login: '/login',
    changePassword: '/change-password',
    forbidden: '/403',
    notFound: '/404',
  },
} as const
