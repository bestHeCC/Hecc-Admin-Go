import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'

export const DEFAULT_LAYOUT_NAME = 'DefaultLayout'

const BlankLayout = () => import('@/views/layouts/BlankLayout.vue')
const DefaultLayout = () => import('@/views/layouts/DefaultLayout.vue')

/** 静态路由：登录、改密、错误页使用 BlankLayout，首页使用 DefaultLayout */
export const staticRoutes: RouteRecordRaw[] = [
  {
    path: '/login',
    component: BlankLayout,
    children: [
      {
        path: '',
        name: 'Login',
        component: () => import('@/views/auth/LoginView.vue'),
        meta: { title: '登录', public: true },
      },
    ],
  },
  {
    path: '/change-password',
    component: BlankLayout,
    children: [
      {
        path: '',
        name: 'ChangePassword',
        component: () => import('@/views/auth/ChangePasswordView.vue'),
        meta: { title: '修改密码', public: true },
      },
    ],
  },
  {
    path: '/403',
    component: BlankLayout,
    children: [
      {
        path: '',
        name: 'Forbidden',
        component: () => import('@/views/pages/ForbiddenView.vue'),
        meta: { title: '无访问权限', public: true },
      },
    ],
  },
  {
    path: '/404',
    component: BlankLayout,
    children: [
      {
        path: '',
        name: 'NotFound',
        component: () => import('@/views/error/NotFoundView.vue'),
        meta: { title: '页面不存在', public: true },
      },
    ],
  },
  {
    path: '/',
    name: DEFAULT_LAYOUT_NAME,
    component: DefaultLayout,
    children: [
      {
        path: '',
        name: 'Home',
        component: () => import('@/views/pages/HomeView.vue'),
        meta: { title: '首页' },
      },
    ],
  },
]

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: staticRoutes,
  scrollBehavior: () => ({ top: 0 }),
})

export default router
