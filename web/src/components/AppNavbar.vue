<script setup lang="ts">
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ArrowDown, Expand, Fold, SwitchButton, User } from '@element-plus/icons-vue'

import NoticeBell from '@/components/NoticeBell.vue'
import { appConfig } from '@/config'
import { useAccountStore } from '@/stores/account'
import { useAppStore } from '@/stores/app'
import { useAuthStore } from '@/stores/auth'

const route = useRoute()
const router = useRouter()
const appStore = useAppStore()
const accountStore = useAccountStore()
const authStore = useAuthStore()

const collapsed = computed(() => appStore.sidebarCollapsed)
const displayName = computed(
  () => accountStore.user?.nickname || accountStore.user?.username || '管理员',
)
const avatarText = computed(() => displayName.value.slice(0, 1).toUpperCase())
const pageTitle = computed(() => route.meta.title || appConfig.title)

async function handleCommand(command: string): Promise<void> {
  if (command === 'profile') {
    ElMessage.info('个人中心功能待实现')
    return
  }

  if (command !== 'logout') return

  try {
    await ElMessageBox.confirm('确定退出登录吗？', '提示', {
      type: 'warning',
      confirmButtonText: '确定',
      cancelButtonText: '取消',
    })
  } catch {
    return
  }

  await authStore.logout()
  appStore.disconnectNotice(true)
  await router.replace(appConfig.routes.login)
}
</script>

<template>
  <div class="navbar">
    <div class="navbar-left">
      <el-tooltip :content="collapsed ? '展开菜单' : '收起菜单'" placement="bottom">
        <el-button text circle aria-label="切换菜单" @click="appStore.toggleSidebar">
          <el-icon :size="18">
            <Expand v-if="collapsed" />
            <Fold v-else />
          </el-icon>
        </el-button>
      </el-tooltip>
      <span class="navbar-title">{{ pageTitle }}</span>
    </div>

    <div class="navbar-right">
      <NoticeBell />

      <el-dropdown trigger="click" @command="handleCommand">
        <span class="user-trigger">
          <el-avatar :size="30" class="user-avatar">{{ avatarText }}</el-avatar>
          <span class="user-name">{{ displayName }}</span>
          <el-icon :size="12"><ArrowDown /></el-icon>
        </span>
        <template #dropdown>
          <el-dropdown-menu>
            <el-dropdown-item command="profile">
              <el-icon><User /></el-icon>
              个人中心
            </el-dropdown-item>
            <el-dropdown-item divided command="logout">
              <el-icon><SwitchButton /></el-icon>
              退出登录
            </el-dropdown-item>
          </el-dropdown-menu>
        </template>
      </el-dropdown>
    </div>
  </div>
</template>

<style scoped>
.navbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 100%;
}

.navbar-left,
.navbar-right {
  display: flex;
  align-items: center;
  gap: 12px;
}

.navbar-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--el-text-color-primary);
}

.user-trigger {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  outline: none;
}

.user-avatar {
  background: var(--el-color-primary);
  font-size: 13px;
}

.user-name {
  max-width: 120px;
  overflow: hidden;
  font-size: 14px;
  color: var(--el-text-color-regular);
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
