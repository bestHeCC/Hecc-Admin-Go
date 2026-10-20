<script setup lang="ts">
import { computed } from 'vue'

import AppBreadcrumb from '@/components/AppBreadcrumb.vue'
import AppNavbar from '@/components/AppNavbar.vue'
import AppSidebar from '@/components/AppSidebar.vue'
import { useAppStore } from '@/stores/app'

const appStore = useAppStore()
const asideWidth = computed(() => (appStore.sidebarCollapsed ? '64px' : '220px'))
</script>

<template>
  <el-container class="app-layout">
    <el-aside :width="asideWidth" class="app-aside">
      <AppSidebar />
    </el-aside>

    <el-container class="app-body">
      <el-header class="app-header" height="56px">
        <AppNavbar />
      </el-header>

      <el-main class="app-main">
        <AppBreadcrumb />
        <router-view v-slot="{ Component }">
          <transition name="fade" mode="out-in">
            <component :is="Component" />
          </transition>
        </router-view>
      </el-main>
    </el-container>
  </el-container>
</template>

<style scoped>
.app-layout {
  height: 100%;
}

.app-aside {
  overflow: hidden;
  transition: width 0.2s ease;
}

.app-body {
  min-width: 0;
  background: var(--el-bg-color-page);
}

.app-header {
  display: flex;
  align-items: center;
  padding: 0 16px;
  background: var(--el-bg-color);
  border-bottom: 1px solid var(--el-border-color-lighter);
}

.app-main {
  padding: 16px;
  overflow-y: auto;
}
</style>
