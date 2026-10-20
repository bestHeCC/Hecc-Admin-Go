<script setup lang="ts">
import { useRouter } from 'vue-router'

import { appConfig } from '@/config'

const router = useRouter()
</script>

<template>
  <div class="error-page">
    <el-result icon="warning" title="403" sub-title="抱歉，您没有访问该页面的权限。">
      <template #extra>
        <el-button type="primary" @click="router.replace(appConfig.routes.home)"
          >返回首页</el-button
        >
      </template>
    </el-result>
  </div>
</template>

<style scoped>
.error-page {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100%;
  background: var(--el-bg-color-page);
}
</style>
