<script setup lang="ts">
import { computed, reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import type { FormInstance, FormRules } from 'element-plus'
import { Lock } from '@element-plus/icons-vue'

import { appConfig } from '@/config'
import { setupDynamicRoutes } from '@/router/dynamic'
import { useAccountStore } from '@/stores/account'
import { useAuthStore } from '@/stores/auth'

interface ChangePasswordForm {
  oldPassword: string
  newPassword: string
  confirmPassword: string
}

const router = useRouter()
const authStore = useAuthStore()
const accountStore = useAccountStore()

const formRef = ref<FormInstance>()
const loading = ref(false)
const form = reactive<ChangePasswordForm>({
  oldPassword: '',
  newPassword: '',
  confirmPassword: '',
})

const forced = computed(() => authStore.mustChangePassword)

const rules: FormRules = {
  oldPassword: [{ required: true, message: '请输入原密码', trigger: 'blur' }],
  newPassword: [
    { required: true, message: '请输入新密码', trigger: 'blur' },
    {
      validator: (_rule, value, callback) => {
        if (value.length < 8 || value.length > 64) {
          callback(new Error('密码长度需为 8-64 位'))
          return
        }
        if (!/[A-Za-z]/.test(value) || !/\d/.test(value)) {
          callback(new Error('密码必须同时包含字母和数字'))
          return
        }
        callback()
      },
      trigger: 'blur',
    },
  ],
  confirmPassword: [
    { required: true, message: '请再次输入新密码', trigger: 'blur' },
    {
      validator: (_rule, value, callback) => {
        if (value !== form.newPassword) {
          callback(new Error('两次输入的密码不一致'))
          return
        }
        callback()
      },
      trigger: ['blur', 'change'],
    },
  ],
}

async function handleSubmit(): Promise<void> {
  if (loading.value) return

  const valid = await formRef.value?.validate().catch(() => false)
  if (!valid) return

  loading.value = true
  try {
    await authStore.changePassword({
      oldPassword: form.oldPassword,
      newPassword: form.newPassword,
    })
    accountStore.reset()
    await accountStore.load()
    setupDynamicRoutes(router, accountStore.menus)
    ElMessage.success('密码修改成功')
    await router.replace(appConfig.routes.home)
  } catch {
    // 请求错误由拦截器提示
  } finally {
    loading.value = false
  }
}

async function handleLogout(): Promise<void> {
  await authStore.logout()
  await router.replace(appConfig.routes.login)
}
</script>

<template>
  <div class="password-page">
    <el-card class="password-card" shadow="never">
      <div class="password-heading">
        <div class="password-icon">
          <el-icon :size="24"><Lock /></el-icon>
        </div>
        <div>
          <h2>{{ forced ? '请修改初始密码' : '修改密码' }}</h2>
          <p>
            {{
              forced
                ? '为保障账号安全，首次登录需修改密码后才能进入系统。'
                : '定期更新密码可以提升账号安全性。'
            }}
          </p>
        </div>
      </div>

      <el-form
        ref="formRef"
        :model="form"
        :rules="rules"
        label-position="top"
        size="large"
        @submit.prevent="handleSubmit"
      >
        <el-form-item label="原密码" prop="oldPassword">
          <el-input
            v-model="form.oldPassword"
            type="password"
            placeholder="请输入原密码"
            autocomplete="current-password"
            show-password
          />
        </el-form-item>

        <el-form-item label="新密码" prop="newPassword">
          <el-input
            v-model="form.newPassword"
            type="password"
            placeholder="请输入新密码"
            autocomplete="new-password"
            show-password
          />
        </el-form-item>

        <el-form-item label="确认新密码" prop="confirmPassword">
          <el-input
            v-model="form.confirmPassword"
            type="password"
            placeholder="请再次输入新密码"
            autocomplete="new-password"
            show-password
            @keyup.enter="handleSubmit"
          />
        </el-form-item>

        <el-button
          class="password-submit"
          type="primary"
          size="large"
          native-type="submit"
          :loading="loading"
        >
          确认修改
        </el-button>
      </el-form>

      <div class="password-footer">
        <el-button link type="primary" @click="handleLogout">退出登录</el-button>
      </div>
    </el-card>
  </div>
</template>

<style scoped>
.password-page {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100%;
  padding: 24px;
  background: radial-gradient(circle at 15% 15%, rgb(64 158 255 / 12%), transparent 32%), #f5f7fa;
}

.password-card {
  width: 100%;
  max-width: 500px;
  padding: 12px;
  border: none;
  border-radius: 16px;
  box-shadow: 0 18px 48px rgb(31 45 61 / 10%);
}

.password-heading {
  display: flex;
  gap: 14px;
  align-items: flex-start;
  margin-bottom: 28px;
}

.password-icon {
  display: flex;
  flex: none;
  align-items: center;
  justify-content: center;
  width: 46px;
  height: 46px;
  color: var(--el-color-primary);
  background: var(--el-color-primary-light-9);
  border-radius: 12px;
}

.password-heading h2 {
  margin: 0 0 6px;
  font-size: 22px;
  color: var(--el-text-color-primary);
}

.password-heading p {
  margin: 0;
  font-size: 13px;
  line-height: 1.6;
  color: var(--el-text-color-secondary);
}

.password-submit {
  width: 100%;
  margin-top: 8px;
}

.password-footer {
  margin-top: 20px;
  text-align: center;
}
</style>
