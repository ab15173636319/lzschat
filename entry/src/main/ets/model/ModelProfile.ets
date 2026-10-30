/**
 * 一套可保存的模型配置
 */
@ObservedV2
export class ModelProfile {
  private static seq: number = 0

  @Trace id: string = ''
  /** 显示名称，例如「DeepSeek 官方」 */
  @Trace name: string = ''
  /** 接口地址：可填 host、host/v1 或完整的 /chat/completions */
  @Trace baseUrl: string = ''
  @Trace apiKey: string = ''
  @Trace model: string = ''
  @Trace temperature: number = 0.7
  /** 每次请求携带的最近消息条数（越多上下文越强，消耗也越大） */
  @Trace contextMessages: number = 40
  /** 最大回复 tokens，0 表示使用服务端默认值 */
  @Trace maxTokens: number = 4096

  constructor() {
    ModelProfile.seq += 1
    this.id = `${Date.now()}-${ModelProfile.seq}`
  }

  /** 默认预置的一套 DeepSeek 配置 */
  static createDefault(): ModelProfile {
    const profile = new ModelProfile()
    profile.name = 'DeepSeek'
    profile.baseUrl = 'https://api.deepseek.com/v1'
    profile.model = 'deepseek-chat'
    return profile
  }

  /** 新增模型时的空白模板 */
  static createBlank(baseUrl: string): ModelProfile {
    const profile = new ModelProfile()
    profile.name = '新模型'
    profile.baseUrl = baseUrl
    profile.model = ''
    return profile
  }

  get isReady(): boolean {
    return this.apiKey.trim().length > 0 && this.baseUrl.trim().length > 0
  }

  /** 用于列表展示的模型名 */
  get displayModel(): string {
    return this.model.trim().length > 0 ? this.model.trim() : '未选择模型'
  }

  /** 上下文条数（2 ~ 200） */
  resolveContextMessages(): number {
    const value = Math.floor(this.contextMessages)
    if (value < 2) {
      return 2
    }
    if (value > 200) {
      return 200
    }
    return value
  }

  /** 最大回复 tokens（0 表示不传，交给服务端默认值；上限 32768） */
  resolveMaxTokens(): number {
    const value = Math.floor(this.maxTokens)
    if (value <= 0) {
      return 0
    }
    if (value > 32768) {
      return 32768
    }
    return value
  }

  /** 把用户填写的接口地址补全成 chat/completions 地址 */
  resolveChatUrl(): string {
    let url = this.baseUrl.trim()
    if (url.length === 0) {
      return ''
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = `https://${url}`
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1)
    }
    if (url.endsWith('/chat/completions')) {
      return url
    }
    return `${url}/chat/completions`
  }

  /** 用另一份配置覆盖当前配置（保留 id） */
  copyFrom(other: ModelProfile): void {
    this.name = other.name
    this.baseUrl = other.baseUrl
    this.apiKey = other.apiKey
    this.model = other.model
    this.temperature = other.temperature
    this.contextMessages = other.contextMessages
    this.maxTokens = other.maxTokens
  }
}
