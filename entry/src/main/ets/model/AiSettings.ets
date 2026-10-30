import { AppStorageV2, PersistenceV2 } from '@kit.ArkUI'
import { ModelProfile } from './ModelProfile'

/** 持久化键：整份配置列表以 JSON 字符串保存，避免嵌套对象反序列化问题 */
const SETTINGS_KEY = 'lzs_ai_settings'
const STORE_KEY = 'lzs_ai_settings_state'

/** 持久化用的 DTO（不能用 @ObservedV2 实例直接 JSON.stringify） */
interface ProfileDto {
  id?: string
  name?: string
  baseUrl?: string
  apiKey?: string
  model?: string
  temperature?: number
  contextMessages?: number
  maxTokens?: number
}

interface SettingsDto {
  activeId?: string
  profiles?: ProfileDto[]
}

/** PersistenceV2 只保存一个字符串字段，读写时机完全由业务控制 */
@ObservedV2
class PersistedSettings {
  @Trace data: string = ''
}

/** 旧版本（单模型配置）的数据结构，仅用于升级迁移 */
@ObservedV2
class LegacyAiConfig {
  @Trace baseUrl: string = ''
  @Trace apiKey: string = ''
  @Trace model: string = ''
  @Trace temperature: number = 1
}

function persistedSettings(): PersistedSettings {
  return PersistenceV2.globalConnect({
    type: PersistedSettings,
    key: SETTINGS_KEY,
    defaultCreator: () => new PersistedSettings()
  })!
}

/** 读取旧版本保存的单套配置，失败时返回 null */
function readLegacyConfig(): LegacyAiConfig | null {
  try {
    const legacy = PersistenceV2.globalConnect({
      type: LegacyAiConfig,
      key: 'lzs_ai_config',
      defaultCreator: () => new LegacyAiConfig()
    })
    return legacy !== undefined ? legacy : null
  } catch (e) {
    return null
  }
}

/**
 * 模型配置集合：可保存多套配置，当前选中一套用于聊天
 */
@ObservedV2
export class AiSettings {
  @Trace profiles: ModelProfile[] = []
  @Trace activeId: string = ''

  /** 当前生效的配置，找不到时回退到第一套 */
  get active(): ModelProfile | null {
    for (const profile of this.profiles) {
      if (profile.id === this.activeId) {
        return profile
      }
    }
    return this.profiles.length > 0 ? this.profiles[0] : null
  }

  get hasProfiles(): boolean {
    return this.profiles.length > 0
  }

  /** 选中某个模型 */
  select(id: string): void {
    for (const profile of this.profiles) {
      if (profile.id === id) {
        this.activeId = id
        return
      }
    }
  }

  /** 新增并选中 */
  add(profile: ModelProfile): void {
    const next = this.profiles.slice()
    next.push(profile)
    this.profiles = next
    this.activeId = profile.id
  }

  /** 更新（按 id 替换） */
  update(profile: ModelProfile): void {
    const next = this.profiles.slice()
    for (let i = 0; i < next.length; i++) {
      if (next[i].id === profile.id) {
        next[i] = profile
        break
      }
    }
    this.profiles = next
  }

  /** 删除，返回是否删除成功 */
  remove(id: string): boolean {
    if (this.profiles.length <= 1) {
      return false
    }
    const next: ModelProfile[] = []
    for (const profile of this.profiles) {
      if (profile.id !== id) {
        next.push(profile)
      }
    }
    this.profiles = next
    if (this.activeId === id) {
      this.activeId = next.length > 0 ? next[0].id : ''
    }
    return true
  }
}

function toDto(profile: ModelProfile): ProfileDto {
  const dto: ProfileDto = {
    id: profile.id,
    name: profile.name,
    baseUrl: profile.baseUrl,
    apiKey: profile.apiKey,
    model: profile.model,
    temperature: profile.temperature,
    contextMessages: profile.contextMessages,
    maxTokens: profile.maxTokens
  }
  return dto
}

/** 把内存里的配置写回持久化 */
export function persistAiSettings(settings: AiSettings): void {
  const profiles: ProfileDto[] = []
  for (const profile of settings.profiles) {
    profiles.push(toDto(profile))
  }
  const dto: SettingsDto = {
    activeId: settings.activeId,
    profiles: profiles
  }
  try {
    persistedSettings().data = JSON.stringify(dto)
    // 立即落盘，避免强杀应用时丢失配置
    PersistenceV2.save(SETTINGS_KEY)
  } catch (e) {
    // 持久化失败不影响本次使用
  }
}

function profileFromDto(dto: ProfileDto): ModelProfile {
  const profile = new ModelProfile()
  if (dto.id !== undefined && dto.id.length > 0) {
    profile.id = dto.id
  }
  profile.name = dto.name !== undefined ? dto.name : ''
  profile.baseUrl = dto.baseUrl !== undefined ? dto.baseUrl : ''
  profile.apiKey = dto.apiKey !== undefined ? dto.apiKey : ''
  profile.model = dto.model !== undefined ? dto.model : ''
  profile.temperature = dto.temperature !== undefined ? dto.temperature : 0.7
  profile.contextMessages = dto.contextMessages !== undefined ? dto.contextMessages : 40
  profile.maxTokens = dto.maxTokens !== undefined ? dto.maxTokens : 4096
  return profile
}

function loadSettings(): AiSettings {
  const settings = new AiSettings()
  const raw = persistedSettings().data
  if (raw.length > 0) {
    try {
      const dto = JSON.parse(raw) as SettingsDto
      const list = dto.profiles
      if (list !== undefined && list.length > 0) {
        const profiles: ModelProfile[] = []
        for (const item of list) {
          profiles.push(profileFromDto(item))
        }
        settings.profiles = profiles
        const activeId = dto.activeId !== undefined ? dto.activeId : ''
        let matched = false
        for (const profile of profiles) {
          if (profile.id === activeId) {
            matched = true
            break
          }
        }
        settings.activeId = matched ? activeId : profiles[0].id
        return settings
      }
    } catch (e) {
      // 数据损坏时回退到默认配置
    }
  }
  const preset = ModelProfile.createDefault()
  // 尝试把旧版本保存的单套配置迁移成一条模型配置
  const legacy = readLegacyConfig()
  if (legacy !== null && legacy.apiKey.trim().length > 0) {
    preset.name = legacy.model.trim().length > 0 ? legacy.model.trim() : 'DeepSeek'
    if (legacy.baseUrl.trim().length > 0) {
      preset.baseUrl = legacy.baseUrl.trim()
    }
    if (legacy.model.trim().length > 0) {
      preset.model = legacy.model.trim()
    }
    preset.apiKey = legacy.apiKey.trim()
    if (legacy.temperature > 0) {
      preset.temperature = legacy.temperature
    }
    settings.profiles = [preset]
    settings.activeId = preset.id
    persistAiSettings(settings)
    return settings
  }
  settings.profiles = [preset]
  settings.activeId = preset.id
  return settings
}

/** 全局唯一的模型配置集合 */
export function useAiSettings(): AiSettings {
  return AppStorageV2.connect(AiSettings, STORE_KEY, () => loadSettings())!
}
