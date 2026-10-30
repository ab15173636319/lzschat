import { AppStorageV2 } from '@kit.ArkUI'
import { AiSettings, useAiSettings } from '../model/AiSettings'
import { ChatMessage, ChatRole, MessageStatus } from '../model/ChatMessage'
import { Conversation, DEFAULT_CONVERSATION_TITLE } from '../model/Conversation'
import { ConversationStore, persistConversations, useConversationStore } from '../model/ConversationStore'
import { ModelProfile } from '../model/ModelProfile'
import { DEFAULT_SYSTEM_PROMPT, PromptSettings, usePromptSettings } from '../model/PromptSettings'
import { ChatApiMessage, ChatService, ChatStreamOptions } from '../service/ChatService'

/** 上下文消息的条数上限（单个模型设置里还能再调小/调大，这里只是全局兜底） */
const MAX_CONTEXT_MESSAGES = 200
/** 上下文消息的总字符预算，避免超长对话撑爆模型上下文窗口（约 3 万字符） */
const MAX_CONTEXT_CHARS = 32000

/**
 * 聊天页面的全局状态（多会话）。
 *
 * - conversations：会话列表（按最近更新时间排序）
 * - messages：当前会话的消息列表（流式内容通过 @Trace 驱动气泡刷新）
 * - isSending：是否正在等待/接收 AI 回复
 * - tick：内容版本号，用来触发消息列表滚动
 */
@ObservedV2
export class ChatStore {
  @Trace isSending: boolean = false
  @Trace tick: number = 0
  @Trace lastError: string = ''

  private service: ChatService = new ChatService()
  private settings: AiSettings = useAiSettings()
  private promptSettings: PromptSettings = usePromptSettings()
  private conversationStore: ConversationStore = useConversationStore()
  /** 请求序号：新请求/停止都会自增，旧请求的异步收尾不能污染新状态 */
  private requestSeq: number = 0

  // ---------------- 会话查询 ----------------

  get conversations(): Conversation[] {
    return this.conversationStore.sorted
  }

  get activeId(): string {
    return this.conversationStore.activeId
  }

  get activeConversation(): Conversation | null {
    return this.conversationStore.active
  }

  get messages(): ChatMessage[] {
    const conversation = this.conversationStore.active
    return conversation !== null ? conversation.messages : []
  }

  /** 按 id 取会话（长按菜单/复制用） */
  getConversation(id: string): Conversation | null {
    return this.conversationStore.find(id)
  }

  get hasMessages(): boolean {
    return this.messages.length > 0
  }

  /** 当前选中的模型是否可用 */
  get configReady(): boolean {
    const profile = this.settings.active
    return profile !== null && profile.isReady
  }

  // ---------------- 会话操作 ----------------

  /**
   * 新建会话并选中
   */
  newChat(): void {
    if (this.isSending) {
      this.stop()
    }
    // 当前已经是空对话时直接复用，避免堆积一堆空会话
    const current = this.conversationStore.active
    if (current !== null && current.messages.length === 0) {
      this.tick += 1
      return
    }
    this.conversationStore.create(DEFAULT_CONVERSATION_TITLE)
    this.lastError = ''
    persistConversations(this.conversationStore)
    this.tick += 1
  }

  /**
   * 切换会话（切换前停止当前回复）
   */
  switchTo(id: string): void {
    if (this.conversationStore.activeId === id) {
      return
    }
    if (this.isSending) {
      this.stop()
    }
    if (this.conversationStore.switchTo(id)) {
      this.tick += 1
      persistConversations(this.conversationStore)
    }
  }

  /**
   * 删除会话，返回是否删除成功（至少保留一个会话）
   */
  deleteConversation(id: string): boolean {
    if (id === this.conversationStore.activeId && this.isSending) {
      this.stop()
    }
    const removed = this.conversationStore.remove(id)
    if (removed) {
      persistConversations(this.conversationStore)
      this.tick += 1
    }
    return removed
  }

  /**
   * 批量删除会话（多选删除）。全部删完时会自动新建一个空会话。
   */
  deleteConversations(ids: string[]): number {
    if (ids.length === 0) {
      return 0
    }
    if (this.isSending && ids.indexOf(this.conversationStore.activeId) >= 0) {
      this.stop()
    }
    const removed = this.conversationStore.removeMany(ids)
    if (removed > 0) {
      if (this.conversationStore.conversations.length === 0) {
        this.conversationStore.create(DEFAULT_CONVERSATION_TITLE)
      }
      persistConversations(this.conversationStore)
      this.tick += 1
    }
    return removed
  }

  /**
   * 删除某条用户消息及其之后的所有消息（消息菜单的「删除」）。
   */
  deleteMessage(conversationId: string, messageId: string): boolean {
    const conversation = this.conversationStore.find(conversationId)
    if (conversation === null) {
      return false
    }
    let index = -1
    for (let i = conversation.messages.length - 1; i >= 0; i--) {
      if (conversation.messages[i].id === messageId) {
        index = i
        break
      }
    }
    if (index < 0) {
      return false
    }
    if (this.isSending && this.conversationStore.activeId === conversationId) {
      this.stop()
    }
    const kept = conversation.messages.slice(0, index)
    conversation.messages = kept
    conversation.updatedAt = Date.now()
    if (kept.length === 0) {
      conversation.title = DEFAULT_CONVERSATION_TITLE
    }
    persistConversations(this.conversationStore)
    this.tick += 1
    return true
  }

  /**
   * 修改某会话最后一条用户消息，并重新生成这一轮回复。
   * 该用户消息之后的所有消息都会被丢弃。
   */
  editLastUserMessage(conversationId: string, newContent: string): boolean {
    const content = newContent.trim()
    if (content.length === 0) {
      return false
    }
    if (this.isSending) {
      this.stop()
    }
    const conversation = this.conversationStore.find(conversationId)
    if (conversation === null) {
      return false
    }
    let userIndex = -1
    for (let i = conversation.messages.length - 1; i >= 0; i--) {
      if (conversation.messages[i].role === ChatRole.USER) {
        userIndex = i
        break
      }
    }
    if (userIndex < 0) {
      return false
    }
    const kept = conversation.messages.slice(0, userIndex)
    const newMessage = new ChatMessage(ChatRole.USER, content)
    kept.push(newMessage)
    conversation.messages = kept
    conversation.updatedAt = Date.now()
    if (conversation.title === DEFAULT_CONVERSATION_TITLE || conversation.title.trim().length === 0) {
      conversation.title = this.makeTitle(content)
    }
    if (this.conversationStore.activeId !== conversation.id) {
      this.conversationStore.switchTo(conversation.id)
    }
    persistConversations(this.conversationStore)
    this.tick += 1
    this.requestCompletion(conversation)
    return true
  }

  // ---------------- 消息操作 ----------------

  /**
   * 发送一条用户消息，并流式获取 AI 回复。
   */
  sendText(text: string): void {
    const content = text.trim()
    if (content.length === 0 || this.isSending) {
      return
    }
    const conversation = this.ensureConversation()
    const userMessage = new ChatMessage(ChatRole.USER, content)
    conversation.addMessage(userMessage)
    if (conversation.title === DEFAULT_CONVERSATION_TITLE || conversation.title.trim().length === 0) {
      conversation.title = this.makeTitle(content)
    }
    persistConversations(this.conversationStore)
    this.tick += 1
    this.requestCompletion(conversation)
  }

  /**
   * 停止当前回复，保留已经生成的内容。
   */
  stop(): void {
    if (!this.isSending) {
      return
    }
    this.requestSeq += 1
    this.service.cancel()
    const conversation = this.conversationStore.active
    if (conversation !== null) {
      const last = this.lastAssistantMessage(conversation)
      if (last !== null && last.status === MessageStatus.STREAMING) {
        last.status = MessageStatus.STOPPED
        if (last.content.trim().length === 0) {
          last.error = '已停止生成'
        }
      }
      conversation.updatedAt = Date.now()
    }
    this.isSending = false
    persistConversations(this.conversationStore)
    this.tick += 1
  }

  /**
   * 重新生成最后一条回复。
   */
  retry(): void {
    if (this.isSending) {
      return
    }
    const conversation = this.conversationStore.active
    if (conversation === null) {
      return
    }
    const kept = conversation.messages.slice()
    while (kept.length > 0 && kept[kept.length - 1].role === ChatRole.ASSISTANT) {
      kept.pop()
    }
    if (kept.length === 0) {
      return
    }
    conversation.messages = kept
    conversation.updatedAt = Date.now()
    persistConversations(this.conversationStore)
    this.requestCompletion(conversation)
  }

  // ---------------- 内部实现 ----------------

  private ensureConversation(): Conversation {
    const conversation = this.conversationStore.active
    if (conversation !== null) {
      return conversation
    }
    return this.conversationStore.create(DEFAULT_CONVERSATION_TITLE)
  }

  private makeTitle(content: string): string {
    const oneLine = content.split('\n').join(' ').trim()
    return oneLine.length > 18 ? `${oneLine.substring(0, 18)}…` : oneLine
  }

  private lastAssistantMessage(conversation: Conversation): ChatMessage | null {
    for (let i = conversation.messages.length - 1; i >= 0; i--) {
      if (conversation.messages[i].role === ChatRole.ASSISTANT) {
        return conversation.messages[i]
      }
    }
    return null
  }

  /**
   * 组装请求历史：系统提示词 + 最近若干条有效消息。
   *
   * 同时受两个限制：
   * - 每个模型配置里的「上下文消息数」（默认 40，最多 200 条）
   * - 总字符预算 MAX_CONTEXT_CHARS，防止超长单条消息 / 长对话超出上下文窗口
   * 从最新消息往前取，保证最新一轮对话一定被带上。
   */
  private buildHistory(conversation: Conversation, skipId: string): ChatApiMessage[] {
    const history: ChatApiMessage[] = []
    const activePrompt = this.promptSettings.activeSystemPrompt
    const promptText = activePrompt !== null && activePrompt.content.trim().length > 0 ?
      activePrompt.content.trim() : DEFAULT_SYSTEM_PROMPT
    const systemMessage: ChatApiMessage = { role: ChatRole.SYSTEM, content: promptText }
    history.push(systemMessage)

    const profile = this.settings.active
    let maxCount = profile !== null ? profile.resolveContextMessages() : 40
    if (maxCount > MAX_CONTEXT_MESSAGES) {
      maxCount = MAX_CONTEXT_MESSAGES
    }

    const selected: ChatApiMessage[] = []
    let usedChars = 0
    const messages = conversation.messages
    for (let i = messages.length - 1; i >= 0; i--) {
      if (selected.length >= maxCount) {
        break
      }
      const message = messages[i]
      if (message.id === skipId) {
        continue
      }
      if (message.content.trim().length === 0) {
        continue
      }
      if (message.status === MessageStatus.ERROR) {
        continue
      }
      const length = message.content.length
      // 最新一条消息即使超预算也要带上
      if (selected.length > 0 && usedChars + length > MAX_CONTEXT_CHARS) {
        break
      }
      const item: ChatApiMessage = { role: message.role, content: message.content }
      selected.push(item)
      usedChars += length
    }
    // selected 是从新到旧，反转成时间顺序
    for (let i = selected.length - 1; i >= 0; i--) {
      history.push(selected[i])
    }
    return history
  }

  /**
   * 发起一次流式补全
   */
  private async requestCompletion(conversation: Conversation): Promise<void> {
    const seq = ++this.requestSeq
    const aiMessage = new ChatMessage(ChatRole.ASSISTANT, '')
    aiMessage.status = MessageStatus.STREAMING
    conversation.addMessage(aiMessage)
    this.isSending = true
    this.lastError = ''
    this.tick += 1
    persistConversations(this.conversationStore)

    const profile: ModelProfile | null = this.settings.active
    const options: ChatStreamOptions = {
      url: profile !== null ? profile.resolveChatUrl() : '',
      apiKey: profile !== null ? profile.apiKey : '',
      model: profile !== null && profile.model.trim().length > 0 ? profile.model.trim() : 'deepseek-chat',
      temperature: profile !== null ? profile.temperature : 0.7,
      maxTokens: profile !== null ? profile.resolveMaxTokens() : 0,
      messages: this.buildHistory(conversation, aiMessage.id),
      onDelta: (delta: string): void => {
        if (seq !== this.requestSeq) {
          return
        }
        aiMessage.content += delta
        this.tick += 1
      }
    }

    try {
      await this.service.stream(options)
      if (seq !== this.requestSeq) {
        return
      }
      if (aiMessage.status === MessageStatus.STREAMING) {
        if (aiMessage.content.trim().length > 0) {
          aiMessage.status = MessageStatus.DONE
        } else {
          aiMessage.status = MessageStatus.ERROR
          aiMessage.error = 'AI 没有返回内容，请检查模型名称后重试'
        }
      }
    } catch (e) {
      if (seq !== this.requestSeq) {
        return
      }
      const error = e as Error
      aiMessage.status = MessageStatus.ERROR
      aiMessage.error = error.message !== undefined && error.message.length > 0 ? error.message : '请求失败，请重试'
      this.lastError = aiMessage.error
    } finally {
      if (seq === this.requestSeq) {
        this.isSending = false
      }
      conversation.updatedAt = Date.now()
      persistConversations(this.conversationStore)
      this.tick += 1
    }
  }
}

/** 全局唯一的聊天状态 */
export function useChat(): ChatStore {
  return AppStorageV2.connect(ChatStore, 'lzs_chat', () => new ChatStore())!
}
