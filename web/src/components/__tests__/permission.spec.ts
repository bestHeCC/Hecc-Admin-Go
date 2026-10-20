import { describe, expect, it } from 'vitest'

import { hasPermission } from '@/utils/permission'

describe('hasPermission', () => {
  it('无权限要求时默认放行', () => {
    expect(hasPermission(undefined, [])).toBe(true)
    expect(hasPermission([], [])).toBe(true)
  })

  it('支持精确权限与任一权限匹配', () => {
    expect(hasPermission('system:user:add', ['system:user:add'])).toBe(true)
    expect(hasPermission(['system:user:add', 'system:user:edit'], ['system:user:edit'])).toBe(true)
    expect(hasPermission('system:user:delete', ['system:user:edit'])).toBe(false)
  })

  it('支持通配、全局通配与超级管理员', () => {
    expect(hasPermission('system:user:add', ['system:*'])).toBe(true)
    expect(hasPermission('system:user:add', ['*'])).toBe(true)
    expect(hasPermission('system:user:add', ['*:*:*'])).toBe(true)
    expect(hasPermission('system:user:add', [], true)).toBe(true)
  })
})
