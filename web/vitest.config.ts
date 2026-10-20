import { fileURLToPath, URL } from 'node:url'

import { defineConfig } from 'vitest/config'

// 单元测试使用 node 环境，纯函数测试无需额外浏览器依赖
export default defineConfig({
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  test: {
    environment: 'node',
    include: ['src/**/__tests__/**/*.spec.ts'],
  },
})
