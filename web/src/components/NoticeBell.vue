<script setup lang="ts">
import { Bell } from '@element-plus/icons-vue'

import { useAppStore } from '@/stores/app'

const appStore = useAppStore()
</script>

<template>
  <el-popover placement="bottom-end" :width="300" trigger="click">
    <template #reference>
      <el-badge
        :value="appStore.unreadCount"
        :max="99"
        :hidden="appStore.unreadCount === 0"
        class="notice-badge"
      >
        <el-button text circle aria-label="通知">
          <el-icon :size="18"><Bell /></el-icon>
        </el-button>
      </el-badge>
    </template>

    <div class="notice-head">
      <span class="notice-head__title">通知</span>
      <span class="notice-head__status" :class="{ 'is-online': appStore.sseConnected }">
        {{ appStore.sseConnected ? '实时连接' : '未连接' }}
      </span>
    </div>
    <el-empty description="暂无新通知" :image-size="56" />
  </el-popover>
</template>

<style scoped>
.notice-badge {
  display: inline-flex;
}

.notice-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-bottom: 8px;
  border-bottom: 1px solid var(--el-border-color-lighter);
}

.notice-head__title {
  font-weight: 600;
}

.notice-head__status {
  color: var(--el-text-color-secondary);
  font-size: 12px;
}

.notice-head__status.is-online {
  color: var(--el-color-success);
}
</style>
