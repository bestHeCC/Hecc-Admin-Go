<script setup lang="ts">
import { computed } from 'vue'
import { RouterLink, useRoute } from 'vue-router'

import { appConfig } from '@/config'
import { useAccountStore } from '@/stores/account'
import { findMenuPath, resolveMenuPath } from '@/utils/tree'

interface BreadcrumbItem {
  title: string
  path?: string
}

const route = useRoute()
const accountStore = useAccountStore()

const items = computed<BreadcrumbItem[]>(() => {
  const menuChain = findMenuPath(accountStore.menus, route.path)
  if (menuChain.length > 0) {
    const result: BreadcrumbItem[] = [{ title: '首页', path: appConfig.routes.home }]
    let parentPath = ''

    menuChain.forEach((menu) => {
      parentPath = resolveMenuPath(parentPath, menu.path)
      result.push({ title: menu.name, path: parentPath })
    })

    return result.filter((item) => item.path !== appConfig.routes.home)
  }

  const matchedItems = route.matched
    .filter((record) => typeof record.meta.title === 'string')
    .map((record) => ({ title: record.meta.title as string, path: record.path }))

  return matchedItems.length > 0 ? matchedItems : [{ title: '首页' }]
})
</script>

<template>
  <el-breadcrumb class="app-breadcrumb" separator="/">
    <el-breadcrumb-item v-for="(item, index) in items" :key="`${item.title}-${index}`">
      <RouterLink v-if="index < items.length - 1 && item.path" :to="item.path">
        {{ item.title }}
      </RouterLink>
      <span v-else>{{ item.title }}</span>
    </el-breadcrumb-item>
  </el-breadcrumb>
</template>

<style scoped>
.app-breadcrumb {
  margin-bottom: 16px;
}

.app-breadcrumb :deep(a) {
  color: var(--el-text-color-secondary);
  text-decoration: none;
}

.app-breadcrumb :deep(a:hover) {
  color: var(--el-color-primary);
}
</style>
