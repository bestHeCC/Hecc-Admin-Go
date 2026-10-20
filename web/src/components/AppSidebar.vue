<script setup lang="ts">
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'

import SidebarMenuItem from '@/components/SidebarMenuItem.vue'
import { appConfig } from '@/config'
import { useAccountStore } from '@/stores/account'
import { useAppStore } from '@/stores/app'
import { isExternalPath } from '@/utils/tree'

const route = useRoute()
const router = useRouter()
const accountStore = useAccountStore()
const appStore = useAppStore()

const collapsed = computed(() => appStore.sidebarCollapsed)
const menus = computed(() => accountStore.menus.filter((menu) => menu.visible !== false))

function handleSelect(index: string): void {
  if (!index || index.startsWith('sub-')) return

  if (isExternalPath(index)) {
    window.open(index, '_blank', 'noopener,noreferrer')
    return
  }

  if (index !== route.path) {
    void router.push(index)
  }
}
</script>

<template>
  <div class="sidebar">
    <div class="sidebar-logo">
      <img class="sidebar-logo__image" src="/favicon.svg" alt="Hecc Admin" />
      <span v-show="!collapsed" class="sidebar-logo__title">{{ appConfig.title }}</span>
    </div>

    <el-scrollbar class="sidebar-menu">
      <el-menu
        :default-active="route.path"
        :collapse="collapsed"
        :collapse-transition="false"
        unique-opened
        @select="handleSelect"
      >
        <SidebarMenuItem v-for="menu in menus" :key="menu.id" :item="menu" />
      </el-menu>
    </el-scrollbar>
  </div>
</template>

<style scoped>
.sidebar {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
  background: #1f2d3d;
}

.sidebar-logo {
  display: flex;
  align-items: center;
  gap: 10px;
  height: 56px;
  padding: 0 16px;
  overflow: hidden;
  color: #fff;
  white-space: nowrap;
  border-bottom: 1px solid rgb(255 255 255 / 8%);
}

.sidebar-logo__image {
  flex: none;
  width: 28px;
  height: 28px;
}

.sidebar-logo__title {
  font-size: 17px;
  font-weight: 600;
  letter-spacing: 0.5px;
}

.sidebar-menu {
  flex: 1;
}

.sidebar :deep(.el-menu) {
  border-right: none;
}

.sidebar :deep(.el-menu-item),
.sidebar :deep(.el-sub-menu__title) {
  color: #c0c4cc;
}

.sidebar :deep(.el-menu-item:hover),
.sidebar :deep(.el-sub-menu__title:hover) {
  color: #fff;
  background-color: rgb(255 255 255 / 8%);
}

.sidebar :deep(.el-menu-item.is-active) {
  color: #fff;
  background-color: var(--el-color-primary);
}
</style>
