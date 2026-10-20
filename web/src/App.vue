<script setup lang="ts">
import { onBeforeUnmount, watch } from 'vue'
import { useRouter } from 'vue-router'
import zhCn from 'element-plus/es/locale/lang/zh-cn'

import { appConfig } from '@/config'
import { useAppStore } from '@/stores/app'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const appStore = useAppStore()
const authStore = useAuthStore()

function handleKick(reason: string): void {
  authStore.clearSession()
  appStore.disconnectNotice(true)
  ElMessage.warning(reason)
  void router.replace(appConfig.routes.login)
}

// token 建立后连接通知 SSE；token 变化（登录/改密/登出）时重建连接
watch(
  () => authStore.token,
  (token) => {
    if (!token) {
      appStore.disconnectNotice(true)
      return
    }

    appStore.disconnectNotice()
    appStore.connectNotice({
      onKick: handleKick,
      onShutdown: (message) => ElMessage.warning(message),
    })
  },
  { immediate: true },
)

onBeforeUnmount(() => {
  appStore.disconnectNotice()
})
</script>

<template>
  <el-config-provider :locale="zhCn">
    <router-view />
  </el-config-provider>
</template>
