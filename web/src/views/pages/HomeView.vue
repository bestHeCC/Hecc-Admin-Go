<script setup lang="ts">
import { computed } from 'vue'

import { appConfig } from '@/config'
import { useAccountStore } from '@/stores/account'

const accountStore = useAccountStore()

const displayName = computed(
  () => accountStore.user?.nickname || accountStore.user?.username || '管理员',
)
const roleText = computed(() => accountStore.roles.join(' / ') || '暂无角色信息')
const menuCount = computed(() => {
  const count = (items: typeof accountStore.menus): number =>
    items.reduce((total, item) => total + 1 + count(item.children ?? []), 0)
  return count(accountStore.menus)
})
</script>

<template>
  <div class="home-page">
    <el-card class="welcome-card" shadow="never">
      <div class="welcome">
        <div>
          <p class="welcome__eyebrow">{{ appConfig.title }}</p>
          <h1>你好，{{ displayName }}</h1>
          <p class="welcome__desc">
            前端骨架已就绪。登录、会话、动态路由、权限指令与实时通知能力可在此基础上继续扩展。
          </p>
          <div class="welcome__tags">
            <el-tag effect="plain">{{ roleText }}</el-tag>
            <el-tag v-if="accountStore.isSuperAdmin" type="danger" effect="plain"
              >超级管理员</el-tag
            >
          </div>
        </div>
        <div class="welcome__avatar">{{ displayName.slice(0, 1).toUpperCase() }}</div>
      </div>
    </el-card>

    <el-row :gutter="16" class="stat-row">
      <el-col :xs="24" :sm="8">
        <el-card shadow="never" class="stat-card">
          <span class="stat-card__label">菜单数量</span>
          <strong class="stat-card__value">{{ menuCount }}</strong>
          <span class="stat-card__hint">由后端菜单树动态注册</span>
        </el-card>
      </el-col>
      <el-col :xs="24" :sm="8">
        <el-card shadow="never" class="stat-card">
          <span class="stat-card__label">权限数量</span>
          <strong class="stat-card__value">{{ accountStore.permissions.length }}</strong>
          <span class="stat-card__hint">按钮权限由 v-hasPerm 控制</span>
        </el-card>
      </el-col>
      <el-col :xs="24" :sm="8">
        <el-card shadow="never" class="stat-card">
          <span class="stat-card__label">角色数量</span>
          <strong class="stat-card__value">{{ accountStore.roles.length }}</strong>
          <span class="stat-card__hint">后端 RBAC 与数据权限自动生效</span>
        </el-card>
      </el-col>
    </el-row>

    <el-card shadow="never" class="next-card">
      <template #header>
        <span class="next-card__title">下一步</span>
      </template>
      <div class="next-list">
        <div class="next-item">
          <strong>接入业务页面</strong>
          <span>按后端菜单的 component 路径在 views 目录中创建页面即可自动挂载。</span>
        </div>
        <div class="next-item">
          <strong>扩展领域服务</strong>
          <span>在 services 中补充接口，在 stores 中维护对应领域状态。</span>
        </div>
        <div class="next-item">
          <strong>完善通知中心</strong>
          <span>SSE 客户端已处理 init / notice / unread / kick / shutdown 事件。</span>
        </div>
      </div>
    </el-card>
  </div>
</template>

<style scoped>
.home-page {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.welcome-card,
.stat-card,
.next-card {
  border: none;
  border-radius: 12px;
}

.welcome {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 24px;
}

.welcome__eyebrow {
  margin: 0 0 8px;
  font-size: 12px;
  font-weight: 600;
  color: var(--el-color-primary);
  letter-spacing: 1.5px;
  text-transform: uppercase;
}

.welcome h1 {
  margin: 0 0 12px;
  font-size: 30px;
  color: var(--el-text-color-primary);
}

.welcome__desc {
  max-width: 680px;
  margin: 0 0 18px;
  line-height: 1.8;
  color: var(--el-text-color-secondary);
}

.welcome__tags {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.welcome__avatar {
  display: flex;
  flex: none;
  align-items: center;
  justify-content: center;
  width: 96px;
  height: 96px;
  font-size: 38px;
  font-weight: 600;
  color: #fff;
  background: linear-gradient(135deg, #409eff, #1d4f91);
  border-radius: 24px;
}

.stat-row {
  row-gap: 16px;
}

.stat-card {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.stat-card__label {
  font-size: 13px;
  color: var(--el-text-color-secondary);
}

.stat-card__value {
  font-size: 30px;
  line-height: 1.2;
  color: var(--el-text-color-primary);
}

.stat-card__hint {
  font-size: 12px;
  color: var(--el-text-color-placeholder);
}

.next-card__title {
  font-weight: 600;
}

.next-list {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 16px;
}

.next-item {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 16px;
  background: var(--el-fill-color-lighter);
  border-radius: 10px;
}

.next-item strong {
  color: var(--el-text-color-primary);
}

.next-item span {
  font-size: 13px;
  line-height: 1.7;
  color: var(--el-text-color-secondary);
}

@media (width <= 900px) {
  .next-list {
    grid-template-columns: 1fr;
  }

  .welcome__avatar {
    display: none;
  }
}
</style>
