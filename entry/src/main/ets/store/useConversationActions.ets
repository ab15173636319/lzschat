import { AppStorageV2 } from '@kit.ArkUI'

/**
 * 会话列表上的交互状态：
 * - 长按菜单（复制 / 修改 / 删除）
 * - 多选删除模式（勾选 + 底部取消/删除）
 * - 修改最后一条用户消息的编辑弹窗
 */
@ObservedV2
export class ConversationActionStore {
  // ---------- 长按菜单 ----------
  @Trace menuVisible: boolean = false
  @Trace menuConversationId: string = ''
  @Trace menuConversationTitle: string = ''

  // ---------- 多选删除 ----------
  @Trace selecting: boolean = false
  @Trace selectedIds: string[] = []

  // ---------- 修改最后一条用户消息 ----------
  @Trace editVisible: boolean = false
  @Trace editConversationId: string = ''
  @Trace editText: string = ''

  // ---------- 点击用户消息弹出的消息菜单 ----------
  @Trace messageMenuVisible: boolean = false
  @Trace messageMenuConversationId: string = ''
  @Trace messageMenuMessageId: string = ''
  @Trace messageMenuContent: string = ''
  private messageMenuSeq: number = 0

  /** 记录长按时间，用来抑制长按松手后触发的点击跳转 */
  private longPressedAt: number = 0
  /** 菜单打开时间，避免长按松手的那一下点击立刻把弹窗关掉 */
  private menuOpenedAt: number = 0

  openMenu(id: string, title: string): void {
    this.menuConversationId = id
    this.menuConversationTitle = title
    this.menuOpenedAt = Date.now()
    this.menuVisible = true
  }

  closeMenu(): void {
    this.menuVisible = false
  }

  /** 刚打开菜单的短暂保护期内，忽略遮罩点击 */
  isMenuJustOpened(): boolean {
    return Date.now() - this.menuOpenedAt < 400
  }

  markLongPress(): void {
    this.longPressedAt = Date.now()
  }

  wasJustLongPressed(): boolean {
    return Date.now() - this.longPressedAt < 800
  }

  enterSelection(): void {
    this.selecting = true
    this.selectedIds = []
  }

  isSelected(id: string): boolean {
    return this.selectedIds.indexOf(id) >= 0
  }

  toggle(id: string): void {
    const next = this.selectedIds.slice()
    const index = next.indexOf(id)
    if (index >= 0) {
      next.splice(index, 1)
    } else {
      next.push(id)
    }
    this.selectedIds = next
  }

  selectedCount(): number {
    return this.selectedIds.length
  }

  /** 取消多选：清空勾选并退出多选模式 */
  cancelSelection(): void {
    this.selectedIds = []
    this.selecting = false
  }

  openEdit(conversationId: string, text: string): void {
    this.editConversationId = conversationId
    this.editText = text
    this.editVisible = true
  }

  closeEdit(): void {
    this.editVisible = false
  }

  /** 点击用户消息呼出菜单，2 秒内无操作自动关闭 */
  openMessageMenu(conversationId: string, messageId: string, content: string): void {
    this.messageMenuSeq += 1
    const seq = this.messageMenuSeq
    this.messageMenuConversationId = conversationId
    this.messageMenuMessageId = messageId
    this.messageMenuContent = content
    this.messageMenuVisible = true
    setTimeout(() => {
      // 期间如果又重新打开/已手动关闭，则忽略这次自动关闭
      if (seq === this.messageMenuSeq && this.messageMenuVisible) {
        this.messageMenuVisible = false
      }
    }, 2000)
  }

  closeMessageMenu(): void {
    this.messageMenuSeq += 1
    this.messageMenuVisible = false
  }
}

export function useConversationActions(): ConversationActionStore {
  return AppStorageV2.connect(ConversationActionStore, 'lzs_conversation_actions',
    () => new ConversationActionStore())!
}
