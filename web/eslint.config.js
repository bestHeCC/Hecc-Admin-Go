import js from '@eslint/js'
import prettier from 'eslint-config-prettier'
import pluginVue from 'eslint-plugin-vue'
import globals from 'globals'
import tseslint from 'typescript-eslint'

// ESLint 9 Flat Config（README 中规划的 .eslintrc.cjs 已改为当前推荐的扁平配置）
export default tseslint.config(
  {
    ignores: [
      'dist/**',
      'node_modules/**',
      'coverage/**',
      'src/auto-imports.d.ts',
      'src/components.d.ts',
    ],
  },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  ...pluginVue.configs['flat/essential'],
  {
    files: ['**/*.vue'],
    languageOptions: {
      globals: {
        ...globals.browser,
        // unplugin-auto-import 注入的 Element Plus 全局 API
        ElMessage: 'readonly',
        ElMessageBox: 'readonly',
      },
      parserOptions: {
        parser: tseslint.parser,
        extraFileExtensions: ['.vue'],
        sourceType: 'module',
      },
    },
  },
  {
    files: ['src/**/*.{ts,vue}'],
    languageOptions: {
      globals: globals.browser,
    },
    rules: {
      'vue/multi-word-component-names': 'off',
    },
  },
  {
    files: ['vite.config.ts', 'vitest.config.ts', 'eslint.config.js'],
    languageOptions: {
      globals: globals.node,
    },
  },
  prettier,
)
