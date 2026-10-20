/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** 应用标题 */
  readonly VITE_APP_TITLE?: string
  /** 接口前缀 */
  readonly VITE_API_BASE_URL?: string
  /** 请求超时时间（毫秒） */
  readonly VITE_API_TIMEOUT?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
