import { AppStorageV2, PersistenceV2 } from '@kit.ArkUI'
import { ChatMessage, ChatRole, MessageStatus } from './ChatMessage'
import { Conversation, DEFAULT_CONVERSATION_TITLE } from './Conversation'

/** 内存 store 键 */
const STORE_KEY = 'lzs_conversations_state'
/** PersistenceV2 持久化键（JSON 快照） */
const PERSIST_KEY = 'lzs_conversations'

/** 最多保留的会话数 */
export const MAX_CONVERSATIONS = 30
/** 每个会话最多保留的消息数（避免持久化数据无限膨胀） */
export const MAX_MESSAGES_PER_CONVERSATION = 500

interface MessageDto {
  id?: string
  role?: string
  content?: string
  status?: string
  error?: string
  createdAt?: number
}

interface ConversationDto {
  id?: string
  title?: string
  createdAt?: number
  updatedAt?: number
  messages?: MessageDto[]
}

interface ConversationsDto {
  activeId?: string
  conversations?: ConversationDto[]
}

/** PersistenceV2 只保存一个字符串字段，读写时机完全由业务控制 */
@ObservedV2
class PersistedConversations {
  @Trace data: string = ''
}

function persistedConversations(): PersistedConversations {
  return PersistenceV2.globalConnect({
    type: PersistedConversations,
    key: PERSIST_KEY,
    defaultCreator: () => new PersistedConversations()
  })!
}

/**
 * 多会话状态：会话列表 + 当前会话。
 * 变更后由调用方调用 persistConversations() 落盘。
 */
@ObservedV2
export class ConversationStore {
  @Trace conversations: Conversation[] = []
  @Trace activeId: string = ''

  /** 当前会话，找不到时回退到第一个 */
  get active(): Conversation | null {
    for (const conversation of this.conversations) {
      if (conversation.id === this.activeId) {
        return conversation
      }
    }
    return this.conversations.length > 0 ? this.conversations[0] : null
  }

  /** 按最近更新时间倒序排列（侧边栏列表） */
  get sorted(): Conversation[] {
    const copy = this.conversations.slice()
    copy.sort((a: Conversation, b: Conversation): number => b.updatedAt - a.updatedAt)
    return copy
  }

  find(id: string): Conversation | null {
    for (const conversation of this.conversations) {
      if (conversation.id === id) {
        return conversation
      }
    }
    return null
  }

  /** 新建会话并选中 */
  create(title: string): Conversation {
    this.trimOverflow()
    const conversation = new Conversation(title)
    const next = this.conversations.slice()
    next.push(conversation)
    this.conversations = next
    this.activeId = conversation.id
    return conversation
  }

  switchTo(id: string): boolean {
    if (this.find(id) === null) {
      return false
    }
    this.activeId = id
    return true
  }

  rename(id: string, title: string): void {
    const conversation = this.find(id)
    if (conversation !== null) {
      conversation.title = title
      conversation.updatedAt = Date.now()
    }
  }

  /** 删除会话，至少保留一个 */
  remove(id: string): boolean {
    if (this.conversations.length <= 1) {
      return false
    }
    const next: Conversation[] = []
    for (const conversation of this.conversations) {
      if (conversation.id !== id) {
        next.push(conversation)
      }
    }
    if (next.length === this.conversations.length) {
      return false
    }
    this.conversations = next
    if (this.activeId === id) {
      this.activeId = next.length > 0 ? next[0].id : ''
    }
    return true
  }

  /**
   * 批量删除会话（多选删除），返回删除数量。
   * 允许删空，由调用方决定是否补一个空会话。
   */
  removeMany(ids: string[]): number {
    if (ids.length === 0) {
      return 0
    }
    const next: Conversation[] = []
    let removed = 0
    for (const conversation of this.conversations) {
      if (ids.indexOf(conversation.id) >= 0) {
        removed += 1
      } else {
        next.push(conversation)
      }
    }
    if (removed === 0) {
      return 0
    }
    this.conversations = next
    if (ids.indexOf(this.activeId) >= 0) {
      this.activeId = next.length > 0 ? next[0].id : ''
    }
    return removed
  }

  /** 会话数超过上限时丢弃最旧的会话 */
  private trimOverflow(): void {
    if (this.conversations.length < MAX_CONVERSATIONS) {
      return
    }
    const sorted = this.sorted
    const keep: Conversation[] = []
    const limit = MAX_CONVERSATIONS - 1
    for (let i = 0; i < limit && i < sorted.length; i++) {
      keep.push(sorted[i])
    }
    this.conversations = keep
  }
}

// ---------------- 序列化 / 反序列化 ----------------

function roleFromString(value: string | undefined): ChatRole {
  switch (value) {
    case 'user':
      return ChatRole.USER
    case 'system':
      return ChatRole.SYSTEM
    default:
      return ChatRole.ASSISTANT
  }
}

function statusFromString(value: string | undefined): MessageStatus {
  switch (value) {
    case 'error':
      return MessageStatus.ERROR
    case 'stopped':
      return MessageStatus.STOPPED
    case 'streaming':
      return MessageStatus.STREAMING
    default:
      return MessageStatus.DONE
  }
}

function messageFromDto(dto: MessageDto): ChatMessage {
  const content = dto.content !== undefined ? dto.content : ''
  let status = statusFromString(dto.status)
  // 上次应用被杀时可能停在 streaming，恢复时按内容判定为完成/中断
  if (status === MessageStatus.STREAMING) {
    status = content.trim().length > 0 ? MessageStatus.DONE : MessageStatus.ERROR
  }
  let error = dto.error !== undefined ? dto.error : ''
  if (status === MessageStatus.ERROR && error.length === 0) {
    error = '上次回复被中断'
  }
  return ChatMessage.restore(
    roleFromString(dto.role),
    content,
    status,
    error,
    dto.id !== undefined ? dto.id : '',
    dto.createdAt !== undefined ? dto.createdAt : 0
  )
}

function messageToDto(message: ChatMessage): MessageDto {
  const dto: MessageDto = {
    id: message.id,
    role: message.role,
    content: message.content,
    status: message.status,
    error: message.error,
    createdAt: message.createdAt
  }
  return dto
}

function conversationFromDto(dto: ConversationDto): Conversation {
  const messages: ChatMessage[] = []
  const list = dto.messages
  if (list !== undefined) {
    for (const item of list) {
      messages.push(messageFromDto(item))
    }
  }
  const title = dto.title !== undefined && dto.title.trim().length > 0 ? dto.title : DEFAULT_CONVERSATION_TITLE
  return Conversation.restore(
    dto.id !== undefined ? dto.id : '',
    title,
    dto.createdAt !== undefined ? dto.createdAt : 0,
    dto.updatedAt !== undefined ? dto.updatedAt : 0,
    messages
  )
}

function conversationToDto(conversation: Conversation): ConversationDto {
  const messages: MessageDto[] = []
  const recent = conversation.messages.slice(-MAX_MESSAGES_PER_CONVERSATION)
  for (const message of recent) {
    messages.push(messageToDto(message))
  }
  const dto: ConversationDto = {
    id: conversation.id,
    title: conversation.title,
    createdAt: conversation.createdAt,
    updatedAt: conversation.updatedAt,
    messages: messages
  }
  return dto
}

/** 把会话列表与当前会话写入 PersistenceV2 */
export function persistConversations(store: ConversationStore): void {
  try {
    const active = store.active
    const sorted = store.sorted
    const kept: Conversation[] = sorted.slice(0, MAX_CONVERSATIONS)
    // 当前会话一定要保存
    if (active !== null) {
      let hasActive = false
      for (const conversation of kept) {
        if (conversation.id === active.id) {
          hasActive = true
          break
        }
      }
      if (!hasActive) {
        kept.push(active)
      }
    }
    const conversations: ConversationDto[] = []
    for (const conversation of kept) {
      conversations.push(conversationToDto(conversation))
    }
    const dto: ConversationsDto = {
      activeId: active !== null ? active.id : store.activeId,
      conversations: conversations
    }
    persistedConversations().data = JSON.stringify(dto)
    PersistenceV2.save(PERSIST_KEY)
  } catch (e) {
    // 持久化失败不影响本次使用
  }
}

function loadConversations(): ConversationStore {
  const store = new ConversationStore()
  const raw = persistedConversations().data
  if (raw.length > 0) {
    try {
      const dto = JSON.parse(raw) as ConversationsDto
      const list = dto.conversations
      if (list !== undefined && list.length > 0) {
        const conversations: Conversation[] = []
        for (const item of list) {
          conversations.push(conversationFromDto(item))
        }
        store.conversations = conversations
        const activeId = dto.activeId !== undefined ? dto.activeId : ''
        let matched = false
        for (const conversation of conversations) {
          if (conversation.id === activeId) {
            matched = true
            break
          }
        }
        store.activeId = matched ? activeId : conversations[0].id
        return store
      }
    } catch (e) {
      // 数据损坏时回退到新会话
    }
  }
  const conversation = new Conversation(DEFAULT_CONVERSATION_TITLE)
  store.conversations = [conversation]
  store.activeId = conversation.id
  return store
}

/** 全局唯一的多会话状态 */
export function useConversationStore(): ConversationStore {
  return AppStorageV2.connect(ConversationStore, STORE_KEY, () => loadConversations())!
}
