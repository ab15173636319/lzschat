import { ChatMessage } from './ChatMessage'

/** 新会话的默认标题 */
export const DEFAULT_CONVERSATION_TITLE = '新对话'

function twoDigits(value: number): string {
  return value < 10 ? `0${value}` : `${value}`
}

/**
 * 一个会话（多轮对话）
 * 会话列表、标题、消息都通过 @Trace 驱动侧边栏/消息区的刷新
 */
@ObservedV2
export class Conversation {
  private static seq: number = 0

  id: string
  @Trace title: string
  @Trace createdAt: number
  @Trace updatedAt: number
  @Trace messages: ChatMessage[] = []

  constructor(title: string) {
    Conversation.seq += 1
    this.id = `${Date.now()}-${Conversation.seq}`
    this.title = title
    this.createdAt = Date.now()
    this.updatedAt = this.createdAt
  }

  /** 从持久化数据恢复 */
  static restore(id: string, title: string, createdAt: number, updatedAt: number,
    messages: ChatMessage[]): Conversation {
    const conversation = new Conversation(title)
    if (id.length > 0) {
      conversation.id = id
    }
    conversation.createdAt = createdAt > 0 ? createdAt : Date.now()
    conversation.updatedAt = updatedAt > 0 ? updatedAt : conversation.createdAt
    conversation.messages = messages
    return conversation
  }

  get hasMessages(): boolean {
    return this.messages.length > 0
  }

  get titleOrDefault(): string {
    return this.title.trim().length > 0 ? this.title : DEFAULT_CONVERSATION_TITLE
  }

  /** 侧边栏预览：最后一条有内容的消息 */
  get preview(): string {
    for (let i = this.messages.length - 1; i >= 0; i--) {
      const text = this.messages[i].content.trim()
      if (text.length > 0) {
        const oneLine = text.split('\n').join(' ')
        return oneLine.length > 40 ? `${oneLine.substring(0, 40)}…` : oneLine
      }
    }
    return '空对话'
  }

  /** 侧边栏时间：今天显示 HH:mm，其他日期显示 MM-DD */
  get timeLabel(): string {
    const date = new Date(this.updatedAt)
    const now = new Date()
    const sameDay = date.getFullYear() === now.getFullYear() &&
      date.getMonth() === now.getMonth() &&
      date.getDate() === now.getDate()
    if (sameDay) {
      return `${twoDigits(date.getHours())}:${twoDigits(date.getMinutes())}`
    }
    return `${twoDigits(date.getMonth() + 1)}-${twoDigits(date.getDate())}`
  }

  /** 追加一条消息并刷新更新时间 */
  addMessage(message: ChatMessage): void {
    const next = this.messages.slice()
    next.push(message)
    this.messages = next
    this.updatedAt = Date.now()
  }
}
