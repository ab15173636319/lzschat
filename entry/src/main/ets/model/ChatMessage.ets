/**
 * 聊天消息的数据模型
 */

/** 消息角色 */
export enum ChatRole {
  SYSTEM = 'system',
  USER = 'user',
  ASSISTANT = 'assistant'
}

/** 消息状态 */
export enum MessageStatus {
  /** 正在流式输出 */
  STREAMING = 'streaming',
  /** 正常结束 */
  DONE = 'done',
  /** 出错 */
  ERROR = 'error',
  /** 用户手动停止 */
  STOPPED = 'stopped'
}

/**
 * 一条聊天消息
 * 使用 @ObservedV2 + @Trace 让流式追加的内容可以驱动 UI 刷新
 */
@ObservedV2
export class ChatMessage {
  private static seq: number = 0

  id: string
  createdAt: number
  @Trace role: ChatRole
  @Trace content: string = ''
  @Trace status: MessageStatus = MessageStatus.DONE
  /** 出错时的错误信息 */
  @Trace error: string = ''

  constructor(role: ChatRole, content: string) {
    ChatMessage.seq += 1
    this.id = `${Date.now()}-${ChatMessage.seq}`
    this.createdAt = Date.now()
    this.role = role
    this.content = content
  }

  /** 从持久化数据恢复（保留原来的 id 与创建时间） */
  static restore(role: ChatRole, content: string, status: MessageStatus, error: string,
    id: string, createdAt: number): ChatMessage {
    const message = new ChatMessage(role, content)
    if (id.length > 0) {
      message.id = id
    }
    if (createdAt > 0) {
      message.createdAt = createdAt
    }
    message.status = status
    message.error = error
    return message
  }
}
