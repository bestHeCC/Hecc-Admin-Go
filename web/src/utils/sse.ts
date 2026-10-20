import { fetchEventSource, EventStreamContentType } from '@microsoft/fetch-event-source'
import type { EventSourceMessage } from '@microsoft/fetch-event-source'

import { appConfig } from '@/config'
import { API_CODE, type ApiResponse } from '@/models/api'
import { getToken, handleSessionExpired } from '@/utils/auth'

/** 通知 SSE 事件 */
export interface NoticeSseEvent {
  type: string
  data: unknown
  raw: EventSourceMessage
}

type NoticeListener = (event: NoticeSseEvent) => void
type StatusListener = (connected: boolean) => void

const RETRY_INTERVAL = 3000

/**
 * 通知 SSE 客户端。
 * 使用 fetch-event-source 以便携带 Bearer Token，并内置断线重连；
 * 模块加载时不会自动建立连接，必须显式调用 connect()。
 */
class NoticeSseClient {
  private controller: AbortController | null = null
  private closedByUser = false
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null
  private readonly listeners = new Set<NoticeListener>()
  private readonly statusListeners = new Set<StatusListener>()

  connect(): void {
    if (this.controller) return

    const token = getToken()
    if (!token) return

    this.closedByUser = false
    const controller = new AbortController()
    this.controller = controller

    void fetchEventSource(appConfig.noticeStreamUrl, {
      method: 'GET',
      headers: {
        Accept: EventStreamContentType,
        Authorization: `Bearer ${token}`,
      },
      signal: controller.signal,
      openWhenHidden: true,
      onopen: async (response) => {
        if (response.status === 401 || response.status === 403) {
          handleSessionExpired('登录状态已失效，请重新登录')
          this.disconnect()
          throw new Error(`SSE 认证失败：HTTP ${response.status}`)
        }

        const contentType = response.headers.get('content-type')
        if (!response.ok || !contentType?.includes(EventStreamContentType)) {
          // 会话失效时后端可能仍返回 HTTP 200 + JSON 响应体
          if (contentType?.includes('application/json')) {
            const body = (await response
              .clone()
              .json()
              .catch(() => null)) as ApiResponse<unknown> | null
            if (body?.code === API_CODE.SESSION_INVALID) {
              handleSessionExpired(body.message || '登录状态已失效，请重新登录')
              this.disconnect()
            }
          }
          throw new Error(`SSE 连接失败：HTTP ${response.status}`)
        }
        this.emitStatus(true)
      },
      onmessage: (message) => {
        this.emitMessage(message)
      },
      onclose: () => {
        this.emitStatus(false)
        if (!this.closedByUser) {
          // 服务端主动断开时抛出异常，交给 onerror 安排重连
          throw new Error('SSE 连接已关闭')
        }
      },
      onerror: (error: unknown) => {
        this.emitStatus(false)
        if (this.closedByUser) throw error
        return RETRY_INTERVAL
      },
    }).catch(() => {
      if (this.controller !== controller) return
      this.controller = null
      this.emitStatus(false)
      if (!this.closedByUser) {
        this.scheduleReconnect()
      }
    })
  }

  /** 主动断开连接，登出或切换账号时调用 */
  disconnect(): void {
    this.closedByUser = true
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer)
      this.reconnectTimer = null
    }
    this.controller?.abort()
    this.controller = null
    this.emitStatus(false)
  }

  /** 订阅通知事件，返回取消订阅函数 */
  subscribe(listener: NoticeListener): () => void {
    this.listeners.add(listener)
    return () => {
      this.listeners.delete(listener)
    }
  }

  /** 订阅连接状态 */
  subscribeStatus(listener: StatusListener): () => void {
    this.statusListeners.add(listener)
    return () => {
      this.statusListeners.delete(listener)
    }
  }

  private emitMessage(message: EventSourceMessage): void {
    let data: unknown = message.data
    if (message.data) {
      try {
        data = JSON.parse(message.data)
      } catch {
        data = message.data
      }
    }

    const event: NoticeSseEvent = {
      type: message.event || 'notice',
      data,
      raw: message,
    }
    this.listeners.forEach((listener) => listener(event))
  }

  private emitStatus(connected: boolean): void {
    this.statusListeners.forEach((listener) => listener(connected))
  }

  private scheduleReconnect(): void {
    if (this.closedByUser || this.reconnectTimer) return
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null
      if (!this.closedByUser) this.connect()
    }, RETRY_INTERVAL)
  }
}

/** 全局通知 SSE 单例（仅实例化，不自动连接） */
export const noticeSse = new NoticeSseClient()
