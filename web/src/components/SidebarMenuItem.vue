<script setup lang="ts">
import { computed } from 'vue'

import type { MenuItem } from '@/models/menu'
import { resolveMenuPath } from '@/utils/tree'

const props = withDefaults(
  defineProps<{
    item: MenuItem
    parentPath?: string
  }>(),
  {
    parentPath: '',
  },
)

const fullPath = computed(() => resolveMenuPath(props.parentPath, props.item.path))
const children = computed(() =>
  (props.item.children ?? []).filter((item) => item.visible !== false),
)
const menuIndex = computed(() => fullPath.value || `sub-${String(props.item.id)}`)
</script>

<template>
  <el-sub-menu v-if="children.length" :index="menuIndex">
    <template #title>
      <el-icon v-if="item.icon">
        <component :is="item.icon" />
      </el-icon>
      <span>{{ item.name }}</span>
    </template>

    <SidebarMenuItem
      v-for="(child, index) in children"
      :key="child.id ?? `${menuIndex}-${index}`"
      :item="child"
      :parent-path="fullPath"
    />
  </el-sub-menu>

  <el-menu-item v-else-if="fullPath" :index="fullPath">
    <el-icon v-if="item.icon">
      <component :is="item.icon" />
    </el-icon>
    <template #title>
      <span>{{ item.name }}</span>
    </template>
  </el-menu-item>
</template>
