<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import type { FormInstance, FormRules } from 'element-plus'
import { Lock, User } from '@element-plus/icons-vue'

import { appConfig } from '@/config'
import { setupDynamicRoutes } from '@/router/dynamic'
import { useAccountStore } from '@/stores/account'
import { useAuthStore } from '@/stores/auth'

interface LoginForm {
  username: string
  password: string
}

const route = useRoute()
const router = useRouter()
const authStore = useAuthStore()
const accountStore = useAccountStore()

const formRef = ref<FormInstance>()
const loading = ref(false)
const form = reactive<LoginForm>({
  username: '',
  password: '',
})

const rules: FormRules = {
  username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
  password: [
    { required: true, message: '请输入密码', trigger: 'blur' },
    { min: 8, message: '密码长度不能少于 8 位', trigger: 'blur' },
  ],
}

function safeRedirect(value: unknown): string {
  if (typeof value !== 'string') return appConfig.routes.home
  if (
    !value.startsWith('/') ||
    value.startsWith('//') ||
    value.startsWith(appConfig.routes.login)
  ) {
    return appConfig.routes.home
  }
  return value
}

async function handleLogin(): Promise<void> {
  if (loading.value) return

  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) return

  loading.value = true
  try {
    await authStore.login(form)

    if (authStore.mustChangePassword) {
      await router.replace(appConfig.routes.changePassword)
      return
    }

    await accountStore.load()
    setupDynamicRoutes(router, accountStore.menus)
    await router.replace(safeRedirect(route.query.redirect))
  } catch {
    // 错误提示由 request 拦截器统一处理
    authStore.clearSession()
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="login-page">
    <section class="login-brand">
      <div class="brand-content">
        <div class="brand-logo">
          <img src="/favicon.svg" alt="Hecc Admin" />
          <span>{{ appConfig.title }}</span>
        </div>
        <h1>安全、清晰、高效的后台管理</h1>
        <p>Vue 3 + TypeScript + Element Plus 前端骨架，已接入会话认证、动态路由与实时通知。</p>
        <ul>
          <li>基于菜单树的动态路由与按钮权限</li>
          <li>统一请求封装与无感会话失效处理</li>
          <li>SSE 实时通知与强制改密流程</li>
        </ul>
      </div>
    </section>

    <section class="login-panel">
      <el-card class="login-card" shadow="never">
        <div class="login-heading">
          <h2>欢迎登录</h2>
          <p>请输入账号和密码进入管理后台</p>
        </div>

        <el-form
          ref="formRef"
          :model="form"
          :rules="rules"
          size="large"
          label-position="top"
          @submit.prevent="handleLogin"
        >
          <el-form-item prop="username">
            <el-input
              v-model="form.username"
              :prefix-icon="User"
              placeholder="用户名"
              autocomplete="username"
              clearable
            />
          </el-form-item>

          <el-form-item prop="password">
            <el-input
              v-model="form.password"
              :prefix-icon="Lock"
              type="password"
              placeholder="密码"
              autocomplete="current-password"
              show-password
              @keyup.enter="handleLogin"
            />
          </el-form-item>

          <el-button
            class="login-submit"
            type="primary"
            size="large"
            native-type="submit"
            :loading="loading"
          >
            登录
          </el-button>
        </el-form>

        <div class="login-hint">默认账号 <code>admin</code>，密码 <code>Admin@123456</code></div>
      </el-card>
    </section>
  </div>
</template>

<style scoped>
.login-page {
  display: grid;
  grid-template-columns: minmax(0, 1.1fr) minmax(420px, 0.9fr);
  min-height: 100%;
  background: #f5f7fa;
}

.login-brand {
  position: relative;
  display: flex;
  align-items: center;
  padding: 64px;
  overflow: hidden;
  color: #fff;
  background:
    radial-gradient(circle at 20% 20%, rgb(255 255 255 / 16%), transparent 36%),
    linear-gradient(135deg, #1f2d3d 0%, #1d4f91 55%, #409eff 100%);
}

.login-brand::after {
  position: absolute;
  right: -120px;
  bottom: -180px;
  width: 460px;
  height: 460px;
  content: '';
  border: 1px solid rgb(255 255 255 / 18%);
  border-radius: 50%;
}

.brand-content {
  position: relative;
  z-index: 1;
  max-width: 560px;
}

.brand-logo {
  display: flex;
  gap: 12px;
  align-items: center;
  margin-bottom: 48px;
  font-size: 20px;
  font-weight: 600;
}

.brand-logo img {
  width: 36px;
  height: 36px;
}

.brand-content h1 {
  margin: 0 0 20px;
  font-size: clamp(30px, 4vw, 46px);
  line-height: 1.25;
}

.brand-content p {
  margin: 0 0 28px;
  font-size: 16px;
  line-height: 1.8;
  color: rgb(255 255 255 / 78%);
}

.brand-content ul {
  padding: 0;
  margin: 0;
  list-style: none;
}

.brand-content li {
  position: relative;
  padding-left: 22px;
  margin-bottom: 14px;
  color: rgb(255 255 255 / 86%);
}

.brand-content li::before {
  position: absolute;
  top: 8px;
  left: 0;
  width: 8px;
  height: 8px;
  content: '';
  background: #fff;
  border-radius: 50%;
}

.login-panel {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 32px;
}

.login-card {
  width: 100%;
  max-width: 420px;
  padding: 12px 16px;
  border: none;
  border-radius: 16px;
  box-shadow: 0 18px 48px rgb(31 45 61 / 10%);
}

.login-heading {
  margin-bottom: 28px;
}

.login-heading h2 {
  margin: 0 0 8px;
  font-size: 26px;
  color: var(--el-text-color-primary);
}

.login-heading p {
  margin: 0;
  font-size: 14px;
  color: var(--el-text-color-secondary);
}

.login-submit {
  width: 100%;
  margin-top: 6px;
}

.login-hint {
  margin-top: 24px;
  font-size: 13px;
  color: var(--el-text-color-secondary);
  text-align: center;
}

.login-hint code {
  padding: 2px 6px;
  color: var(--el-color-primary);
  background: var(--el-color-primary-light-9);
  border-radius: 4px;
}

@media (width <= 900px) {
  .login-page {
    grid-template-columns: 1fr;
  }

  .login-brand {
    display: none;
  }

  .login-panel {
    min-height: 100vh;
    padding: 20px;
  }
}
</style>
