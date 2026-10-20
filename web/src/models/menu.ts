/** 后端菜单树节点 */
export interface MenuItem {
  id: number | string
  parentId?: number | string | null
  name: string
  path?: string | null
  component?: string | null
  permission?: string | null
  icon?: string | null
  children?: MenuItem[]
  visible?: boolean
  [key: string]: unknown
}
