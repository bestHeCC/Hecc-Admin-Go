import { createApp } from 'vue'
import { createPinia } from 'pinia'
import * as ElementPlusIconsVue from '@element-plus/icons-vue'

import App from '@/App.vue'
import '@/assets/styles/index.css'
import hasPermDirective from '@/directives/hasPerm'
import router from '@/router'
import { setupRouterGuards } from '@/router/guard'

const app = createApp(App)
const pinia = createPinia()

app.use(pinia)

// 全量注册 Element Plus 图标，动态菜单可通过图标名直接渲染
for (const [name, component] of Object.entries(ElementPlusIconsVue)) {
  app.component(name, component)
}

app.directive('hasPerm', hasPermDirective)

setupRouterGuards(router)
app.use(router)

app.mount('#app')
