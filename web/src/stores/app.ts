import { ref } from 'vue'
import { defineStore } from 'pinia'

import { appConfig } from '@/config'
import { getStorage, setStorage } from '@/utils/storage'
import { getToken } from '@/utils/auth'
import { noticeSse, type NoticeSseEvent } from '@/utils/sse'

export interface NoticeStreamHandlers {
  onKick?: (reason: string) => void
  onShutdown?: (message: string) => void
  onNotice?: (event: NoticeSseEvent) => void
}

function toUnreadCount(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) return Math.max(0, value)
  if (!value || typeof value !== 'object') return null

  const record = value as Record<string, unknown>
  for (const key of ['unreadCount', 'unread', 'count', 'total']) {
    const item = record[key]
    if (typeof item === 'number' && Number.isFinite(item)) return Math.max(0, item)
  }
  return null
}

function readMessage(value: unknown): string {
  if (typeof value === 'string') return value
  if (!value || typeof value !== 'object') return ''
  const record = value as Record<string, unknown>
  for (const key of ['message', 'reason', 'msg']) {
    if (typeof record[key] === 'string') return record[key]
  }
  return ''
}

/** 应用级 UI 与实时通知状态 */
export const useAppStore = defineStore('app', () => {
  const sidebarCollapsed = ref(getStorage<boolean>(appConfig.storageKeys.sidebarCollapsed) ?? false)
  const unreadCount = ref(0)
  const sseConnected = ref(false)

  let unsubscribeNotice: (() => void) | null = null
  let unsubscribeStatus: (() => void) | null = null

  function toggleSidebar(): void {
    sidebarCollapsed.value = !sidebarCollapsed.value
    setStorage(appConfig.storageKeys.sidebarCollapsed, sidebarCollapsed.value)
  }

  function setUnreadCount(count: number): void {
    unreadCount.value = Math.max(0, count)
  }

  function connectNotice(handlers: NoticeStreamHandlers = {}): void {
    if (unsubscribeNotice || !getToken()) return

    unsubscribeStatus = noticeSse.subscribeStatus((connected) => {
      sseConnected.value = connected
    })
    unsubscribeNotice = noticeSse.subscribe((event) => {
      switch (event.type) {
        case 'init':
        case 'unread': {
          const count = toUnreadCount(event.data)
          if (count !== null) setUnreadCount(count)
          break
        }
        case 'notice': {
          const count = toUnreadCount(event.data)
          setUnreadCount(count ?? unreadCount.value + 1)
          handlers.onNotice?.(event)
          break
        }
        case 'kick': {
          const reason = readMessage(event.data) || '您已被下线，请重新登录'
          disconnectNotice(true)
          handlers.onKick?.(reason)
          break
        }
        case 'shutdown': {
          handlers.onShutdown?.(readMessage(event.data) || '服务已停机')
          break
        }
        default:
          break
      }
    })

    noticeSse.connect()
  }

  function disconnectNotice(resetUnread = false): void {
    unsubscribeNotice?.()
    unsubscribeStatus?.()
    unsubscribeNotice = null
    unsubscribeStatus = null
    sseConnected.value = false
    noticeSse.disconnect()
    if (resetUnread) unreadCount.value = 0
  }

  return {
    sidebarCollapsed,
    unreadCount,
    sseConnected,
    toggleSidebar,
    setUnreadCount,
    connectNotice,
    disconnectNotice,
  }
})
