/** 带 JSON 序列化的 localStorage 封装，读写失败时静默降级 */
export function getStorage<T>(key: string, fallback: T | null = null): T | null {
  try {
    const raw = window.localStorage.getItem(key)
    if (raw === null) return fallback
    return JSON.parse(raw) as T
  } catch {
    return fallback
  }
}

export function setStorage<T>(key: string, value: T): void {
  try {
    window.localStorage.setItem(key, JSON.stringify(value))
  } catch {
    // 忽略隐私模式或存储配额异常
  }
}

export function removeStorage(key: string): void {
  try {
    window.localStorage.removeItem(key)
  } catch {
    // 忽略存储异常
  }
}
