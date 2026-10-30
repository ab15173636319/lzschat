import { AppStorageV2, PersistenceV2 } from '@kit.ArkUI'
import { PromptItem } from './PromptItem'

/** 内存 store 键 */
const STORE_KEY = 'lzs_prompts_state'
/** PersistenceV2 持久化键 */
const PERSIST_KEY = 'lzs_prompts'

/** 没有自定义系统提示词时使用的兜底文案 */
export const DEFAULT_SYSTEM_PROMPT = '你是一个乐于助人的助手，请用简洁、准确的中文回答问题，脱离机械感。'

interface PromptDto {
  id?: string
  name?: string
  content?: string
}

interface PromptsDto {
  activeSystemId?: string
  systemPrompts?: PromptDto[]
  userPrompts?: PromptDto[]
}

/** PersistenceV2 只保存一个字符串字段 */
@ObservedV2
class PersistedPrompts {
  @Trace data: string = ''
}

function persistedPrompts(): PersistedPrompts {
  return PersistenceV2.globalConnect({
    type: PersistedPrompts,
    key: PERSIST_KEY,
    defaultCreator: () => new PersistedPrompts()
  })!
}

/**
 * 提示词库：多套系统提示词（选一套生效）+ 多条常用提示词（空态快捷发送）
 */
@ObservedV2
export class PromptSettings {
  @Trace systemPrompts: PromptItem[] = []
  @Trace userPrompts: PromptItem[] = []
  @Trace activeSystemId: string = ''

  /** 当前生效的系统提示词，找不到时回退到第一套 */
  get activeSystemPrompt(): PromptItem | null {
    for (const item of this.systemPrompts) {
      if (item.id === this.activeSystemId) {
        return item
      }
    }
    return this.systemPrompts.length > 0 ? this.systemPrompts[0] : null
  }

  get activeSystemName(): string {
    const item = this.activeSystemPrompt
    return item !== null ? item.displayName : '默认提示词'
  }

  selectSystem(id: string): void {
    for (const item of this.systemPrompts) {
      if (item.id === id) {
        this.activeSystemId = id
        return
      }
    }
  }

  /** 新增系统提示词（并选中） */
  addSystem(item: PromptItem): void {
    const next = this.systemPrompts.slice()
    item.content = "脱离机械感，增加情感内容" + item.content
    next.push(item)
    this.systemPrompts = next
    this.activeSystemId = item.id
  }

  updateSystem(item: PromptItem): void {
    const next = this.systemPrompts.slice()
    for (let i = 0; i < next.length; i++) {
      if (next[i].id === item.id) {
        next[i] = item
        break
      }
    }
    this.systemPrompts = next
  }

  /** 删除系统提示词，至少保留一套 */
  removeSystem(id: string): boolean {
    if (this.systemPrompts.length <= 1) {
      return false
    }
    const next: PromptItem[] = []
    for (const item of this.systemPrompts) {
      if (item.id !== id) {
        next.push(item)
      }
    }
    this.systemPrompts = next
    if (this.activeSystemId === id) {
      this.activeSystemId = next.length > 0 ? next[0].id : ''
    }
    return true
  }

  addUser(item: PromptItem): void {
    const next = this.userPrompts.slice()
    next.push(item)
    this.userPrompts = next
  }

  updateUser(item: PromptItem): void {
    const next = this.userPrompts.slice()
    for (let i = 0; i < next.length; i++) {
      if (next[i].id === item.id) {
        next[i] = item
        break
      }
    }
    this.userPrompts = next
  }

  removeUser(id: string): boolean {
    const next: PromptItem[] = []
    let removed = false
    for (const item of this.userPrompts) {
      if (item.id === id) {
        removed = true
      } else {
        next.push(item)
      }
    }
    if (removed) {
      this.userPrompts = next
    }
    return removed
  }

  findSystem(id: string): PromptItem | null {
    for (const item of this.systemPrompts) {
      if (item.id === id) {
        return item
      }
    }
    return null
  }

  findUser(id: string): PromptItem | null {
    for (const item of this.userPrompts) {
      if (item.id === id) {
        return item
      }
    }
    return null
  }
}

function promptToDto(item: PromptItem): PromptDto {
  const dto: PromptDto = { id: item.id, name: item.name, content: item.content }
  return dto
}

function promptFromDto(dto: PromptDto): PromptItem {
  return PromptItem.restore(
    dto.name !== undefined ? dto.name : '',
    dto.content !== undefined ? dto.content : '',
    dto.id !== undefined ? dto.id : ''
  )
}

/** 写入 PersistenceV2 */
export function persistPrompts(settings: PromptSettings): void {
  try {
    const systemPrompts: PromptDto[] = []
    for (const item of settings.systemPrompts) {
      systemPrompts.push(promptToDto(item))
    }
    const userPrompts: PromptDto[] = []
    for (const item of settings.userPrompts) {
      userPrompts.push(promptToDto(item))
    }
    const dto: PromptsDto = {
      activeSystemId: settings.activeSystemId,
      systemPrompts: systemPrompts,
      userPrompts: userPrompts
    }
    persistedPrompts().data = JSON.stringify(dto)
    PersistenceV2.save(PERSIST_KEY)
  } catch (e) {
    // 持久化失败不影响本次使用
  }
}

function defaultSystemPrompts(): PromptItem[] {
  return [
    new PromptItem('通用助手', DEFAULT_SYSTEM_PROMPT),
    new PromptItem('代码助手',
      '你是一名资深软件工程师。回答技术问题时先给出结论，再给出可以直接运行的代码示例，并简要解释关键点，避免空话。'),
    new PromptItem('翻译润色',
      '你是一名专业的中英翻译与文字润色助手。只输出最终结果，不要解释过程；保持原文语气，中文表达要自然地道。')
  ]
}

function defaultUserPrompts(): PromptItem[] {
  return [
    new PromptItem('自我介绍', '用一句话介绍一下你自己'),
    new PromptItem('ArkTS 示例', '帮我写一个 ArkTS 的 @ObservedV2 示例'),
    new PromptItem('流式输出', '解释一下大模型的「流式输出」')
  ]
}

function loadPrompts(): PromptSettings {
  const settings = new PromptSettings()
  const raw = persistedPrompts().data
  if (raw.length > 0) {
    try {
      const dto = JSON.parse(raw) as PromptsDto
      const systemList = dto.systemPrompts
      const userList = dto.userPrompts
      if (systemList !== undefined && systemList.length > 0) {
        const systemPrompts: PromptItem[] = []
        for (const item of systemList) {
          systemPrompts.push(promptFromDto(item))
        }
        settings.systemPrompts = systemPrompts
        const activeId = dto.activeSystemId !== undefined ? dto.activeSystemId : ''
        let matched = false
        for (const item of systemPrompts) {
          if (item.id === activeId) {
            matched = true
            break
          }
        }
        settings.activeSystemId = matched ? activeId : systemPrompts[0].id
      }
      if (userList !== undefined) {
        const userPrompts: PromptItem[] = []
        for (const item of userList) {
          userPrompts.push(promptFromDto(item))
        }
        settings.userPrompts = userPrompts
      }
      if (settings.systemPrompts.length > 0) {
        return settings
      }
    } catch (e) {
      // 数据损坏时回退到默认提示词
    }
  }
  const systemPrompts = defaultSystemPrompts()
  settings.systemPrompts = systemPrompts
  settings.activeSystemId = systemPrompts[0].id
  settings.userPrompts = defaultUserPrompts()
  return settings
}

/** 全局唯一的提示词库 */
export function usePromptSettings(): PromptSettings {
  return AppStorageV2.connect(PromptSettings, STORE_KEY, () => loadPrompts())!
}
