import { AiSettings, persistAiSettings, useAiSettings } from '../model/AiSettings'
import { ModelProfile } from '../model/ModelProfile'
import { BalanceStore, useBalance } from '../store/useBalance'
import { ModelDialogState, useModelDialog } from '../store/useModelDialog'

/**
 * 模型配置弹窗
 *
 * - 列表视图：查看已保存的多套模型，点选一套用于当前对话，展示当前模型账户余额
 * - 编辑视图：新增 / 修改一套模型（名称、接口地址、API Key、模型名）
 */
@ComponentV2
export default struct ModelConfigDialog {
  settings: AiSettings = useAiSettings()
  dialog: ModelDialogState = useModelDialog()
  balance: BalanceStore = useBalance()

  @Local editing: boolean = false
  /** 正在编辑的配置 id，空字符串表示新增 */
  @Local editingId: string = ''
  @Local draftName: string = ''
  @Local draftBaseUrl: string = ''
  @Local draftApiKey: string = ''
  @Local draftModel: string = ''
  @Local draftContext: string = ''
  @Local draftMaxTokens: string = ''

  aboutToAppear(): void {
    // 打开弹窗时收起输入框焦点，避免键盘占掉弹窗空间
    try {
      this.getUIContext().getFocusController().clearFocus()
    } catch (e) {
      // 忽略
    }
    // 自动查询当前模型余额（DeepSeek 提供 /user/balance；其他服务点击刷新时再尝试）
    const active = this.settings.active
    if (active !== null && active.isReady && this.isDeepSeekProfile(active)) {
      this.balance.refresh(active)
    }
  }

  private isDeepSeekProfile(profile: ModelProfile): boolean {
    return profile.baseUrl.toLowerCase().indexOf('deepseek') >= 0
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message,
        duration: 1600
      })
    } catch (e) {
      // 页面未挂载时忽略
    }
  }

  private findProfile(id: string): ModelProfile | null {
    for (const profile of this.settings.profiles) {
      if (profile.id === id) {
        return profile
      }
    }
    return null
  }

  private refreshBalance(): void {
    const active = this.settings.active
    if (active === null) {
      this.toast('请先添加模型配置')
      return
    }
    if (!active.isReady) {
      this.toast('请先填写 API Key')
      return
    }
    this.balance.refresh(active)
  }

  private activeBalanceSummary(): string {
    const active = this.settings.active
    if (active !== null && this.balance.isFor(active.id)) {
      return this.balance.summary
    }
    return ''
  }

  private activeBalanceDetail(): string {
    const active = this.settings.active
    if (active !== null && this.balance.isFor(active.id)) {
      return this.balance.detail
    }
    return ''
  }

  private parseNumber(text: string, fallback: number): number {
    const trimmed = text.trim()
    if (trimmed.length === 0) {
      return fallback
    }
    const value = Number(trimmed)
    if (Number.isNaN(value)) {
      return fallback
    }
    return Math.floor(value)
  }

  private startCreate(): void {
    const active = this.settings.active
    this.editingId = ''
    this.draftName = `模型 ${this.settings.profiles.length + 1}`
    this.draftBaseUrl = active !== null ? active.baseUrl : ''
    this.draftApiKey = ''
    this.draftModel = ''
    this.draftContext = '40'
    this.draftMaxTokens = '4096'
    this.editing = true
  }

  private startEdit(profile: ModelProfile): void {
    this.editingId = profile.id
    this.draftName = profile.name
    this.draftBaseUrl = profile.baseUrl
    this.draftApiKey = profile.apiKey
    this.draftModel = profile.model
    this.draftContext = `${profile.contextMessages}`
    this.draftMaxTokens = `${profile.maxTokens}`
    this.editing = true
  }

  private selectProfile(profile: ModelProfile): void {
    this.settings.select(profile.id)
    persistAiSettings(this.settings)
    this.dialog.close()
    const name = profile.name.trim().length > 0 ? profile.name : profile.displayModel
    this.toast(`已切换到 ${name}`)
  }

  private saveDraft(): void {
    const baseUrl = this.draftBaseUrl.trim()
    const model = this.draftModel.trim()
    if (baseUrl.length === 0) {
      this.toast('请填写接口地址')
      return
    }
    if (model.length === 0) {
      this.toast('请填写模型名称')
      return
    }
    const name = this.draftName.trim().length > 0 ? this.draftName.trim() : model
    let contextMessages = this.parseNumber(this.draftContext, 40)
    if (contextMessages < 2) {
      contextMessages = 2
    }
    if (contextMessages > 200) {
      contextMessages = 200
    }
    let maxTokens = this.parseNumber(this.draftMaxTokens, 4096)
    if (maxTokens < 0) {
      maxTokens = 0
    }
    if (maxTokens > 32768) {
      maxTokens = 32768
    }

    if (this.editingId.length === 0) {
      const profile = ModelProfile.createBlank(baseUrl)
      profile.name = name
      profile.baseUrl = baseUrl
      profile.apiKey = this.draftApiKey.trim()
      profile.model = model
      profile.contextMessages = contextMessages
      profile.maxTokens = maxTokens
      this.settings.add(profile)
      this.toast(`已添加并切换到 ${name}`)
    } else {
      const existing = this.findProfile(this.editingId)
      if (existing === null) {
        this.toast('配置不存在，请重新选择')
        return
      }
      existing.name = name
      existing.baseUrl = baseUrl
      existing.apiKey = this.draftApiKey.trim()
      existing.model = model
      existing.contextMessages = contextMessages
      existing.maxTokens = maxTokens
      this.toast('配置已保存')
    }
    persistAiSettings(this.settings)
    this.dialog.close()
  }

  private deleteCurrent(): void {
    if (this.editingId.length === 0) {
      return
    }
    if (!this.settings.remove(this.editingId)) {
      this.toast('至少保留一套模型配置')
      return
    }
    persistAiSettings(this.settings)
    this.toast('已删除')
    this.dialog.close()
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 遮罩
      Column()
        .width("100%")
        .height("100%")
        .backgroundColor('#66000000')
        .onClick(() => this.dialog.close())

      // 弹窗卡片
      Column() {
        if (this.editing) {
          this.buildEditor()
        } else {
          this.buildList()
        }
      }
      .width("88%")
      .constraintSize({ maxWidth: 440, maxHeight: '82%' })
      .padding(20)
      .backgroundColor($r("app.color.card_bg"))
      .borderRadius(22)
      .clip(true)
      .shadow({ radius: 30, color: '#33000000', offsetX: 0, offsetY: 12 })
    }
    .width("100%")
    .height("100%")
  }

  // ---------------- 列表视图 ----------------

  @Builder
  buildList() {
    Column() {
      Row() {
        Text('模型配置')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r("app.color.primary_font_color"))

        Blank()

        Button({ stateEffect: false }) {
          Text('×')
            .fontSize(24)
            .fontColor($r("app.color.text_secondary"))
        }
        .width(34)
        .height(34)
        .backgroundColor(Color.Transparent)
        .onClick(() => this.dialog.close())
      }
      .width("100%")
      .height(40)

      Text('保存多套模型配置，聊天时使用选中的那一套')
        .width("100%")
        .fontSize(12)
        .fontColor($r("app.color.text_secondary"))
        .margin({ top: 4, bottom: 12 })

      // 账户余额（DeepSeek /user/balance）
      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text('账户余额')
            .fontSize(12)
            .fontColor($r("app.color.text_secondary"))
          if (this.balance.loading) {
            Text('查询中…')
              .layoutWeight(1)
              .fontSize(12)
              .fontColor($r("app.color.text_secondary"))
          } else if (this.balance.error.length > 0) {
            Text(this.balance.error)
              .layoutWeight(1)
              .fontSize(11)
              .fontColor($r("app.color.error_text"))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          } else if (this.activeBalanceSummary().length > 0) {
            Text(this.activeBalanceSummary())
              .layoutWeight(1)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r("app.color.primary_font_color"))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          } else {
            Text('未查询')
              .layoutWeight(1)
              .fontSize(11)
              .fontColor($r("app.color.text_secondary"))
          }
          Button(this.balance.loading ? '查询中' : '刷新')
            .height(28)
            .fontSize(12)
            .fontColor($r("app.color.primary_font_color"))
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: $r("app.color.card_border") })
            .borderRadius(14)
            .padding({ left: 10, right: 10 })
            .enabled(!this.balance.loading)
            .onClick(() => this.refreshBalance())
        }
        .width("100%")

        if (this.activeBalanceDetail().length > 0) {
          Text(this.activeBalanceDetail())
            .width("100%")
            .fontSize(10)
            .fontColor($r("app.color.text_secondary"))
            .maxLines(2)
        }
      }
      .width("100%")
      .padding({ left: 12, right: 8, top: 8, bottom: 8 })
      .backgroundColor($r("app.color.card_sub_bg"))
      .borderRadius(12)
      .margin({ bottom: 12 })

      Scroll() {
        Column({ space: 8 }) {
          ForEach(this.settings.profiles, (profile: ModelProfile) => {
            this.buildProfileRow(profile)
          }, (profile: ModelProfile) => profile.id)

          Button('+ 新增模型')
            .width("100%")
            .height(42)
            .fontSize(14)
            .fontColor($r("app.color.primary_font_color"))
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: $r("app.color.card_border") })
            .borderRadius(21)
            .margin({ top: 6 })
            .onClick(() => this.startCreate())
        }
        .width("100%")
      }
      .width("100%")
      .constraintSize({ maxHeight: 340 })
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width("100%")
  }

  @Builder
  buildProfileRow(profile: ModelProfile) {
    Row({ space: 10 }) {
      // 点击区域：选中该模型
      Row({ space: 12 }) {
        // 单选指示器
        Stack() {
          Row()
            .width(18)
            .height(18)
            .borderRadius(9)
            .border({
              width: 1.5,
              color: this.settings.activeId === profile.id ?
                $r("app.color.primary_font_color") : $r("app.color.card_border")
            })
          if (this.settings.activeId === profile.id) {
            Row()
              .width(8)
              .height(8)
              .borderRadius(4)
              .backgroundColor($r("app.color.primary_font_color"))
          }
        }
        .width(18)
        .height(18)

        Column({ space: 3 }) {
          Row({ space: 6 }) {
            Text(profile.name.length > 0 ? profile.name : '未命名模型')
              .fontSize(14)
              .fontColor($r("app.color.primary_font_color"))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: '70%' })
            if (!profile.isReady) {
              Text('未配置 Key')
                .fontSize(10)
                .fontColor($r("app.color.error_text"))
                .backgroundColor($r("app.color.error_bg"))
                .borderRadius(4)
                .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            }
          }
          .width("100%")

          Text(`${profile.displayModel} · ${profile.baseUrl}`)
            .width("100%")
            .fontSize(11)
            .fontColor($r("app.color.text_secondary"))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .onClick(() => this.selectProfile(profile))

      Button('编辑')
        .fontSize(12)
        .fontColor($r("app.color.text_secondary"))
        .backgroundColor(Color.Transparent)
        .height(28)
        .padding({ left: 8, right: 8 })
        .onClick(() => this.startEdit(profile))
    }
    .width("100%")
    .padding({ left: 12, right: 8, top: 10, bottom: 10 })
    .borderRadius(14)
    .backgroundColor(this.settings.activeId === profile.id ?
      $r("app.color.card_sub_bg") : Color.Transparent)
  }

  // ---------------- 编辑视图 ----------------

  @Builder
  buildEditor() {
    Column() {
      Row({ space: 8 }) {
        Button({ stateEffect: false }) {
          Text('‹ 返回')
            .fontSize(14)
            .fontColor($r("app.color.text_secondary"))
        }
        .height(32)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.editing = false
        })

        Text(this.editingId.length === 0 ? '新增模型' : '编辑模型')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r("app.color.primary_font_color"))

        Button('保存')
          .height(32)
          .fontSize(13)
          .fontColor($r("app.color.start_window_background"))
          .backgroundColor($r("app.color.primary_font_color"))
          .borderRadius(16)
          .padding({ left: 14, right: 14 })
          .onClick(() => this.saveDraft())
      }
      .width("100%")
      .height(44)

      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 6 }) {
            Text('名称')
              .width("100%")
              .fontSize(12)
              .fontColor($r("app.color.text_secondary"))
            TextInput({ text: this.draftName, placeholder: '例如 DeepSeek 官方' })
              .width("100%")
              .height(42)
              .fontSize(14)
              .fontColor($r("app.color.primary_font_color"))
              .placeholderColor($r("app.color.input_placeholder"))
              .backgroundColor($r("app.color.card_sub_bg"))
              .borderRadius(10)
              .padding({ left: 12, right: 12 })
              .onChange((value: string) => {
                this.draftName = value
              })
          }
          .width("100%")

          Column({ space: 6 }) {
            Text('接口地址')
              .width("100%")
              .fontSize(12)
              .fontColor($r("app.color.text_secondary"))
            TextInput({ text: this.draftBaseUrl, placeholder: 'https://api.deepseek.com/v1' })
              .width("100%")
              .height(42)
              .fontSize(14)
              .fontColor($r("app.color.primary_font_color"))
              .placeholderColor($r("app.color.input_placeholder"))
              .backgroundColor($r("app.color.card_sub_bg"))
              .borderRadius(10)
              .padding({ left: 12, right: 12 })
              .onChange((value: string) => {
                this.draftBaseUrl = value
              })
            Text('兼容 OpenAI 协议，可填到 /v1')
              .width("100%")
              .fontSize(11)
              .fontColor($r("app.color.text_secondary"))
          }
          .width("100%")

          Column({ space: 6 }) {
            Text('API Key')
              .width("100%")
              .fontSize(12)
              .fontColor($r("app.color.text_secondary"))
            TextInput({ text: this.draftApiKey, placeholder: 'sk-...' })
              .type(InputType.Password)
              .showPasswordIcon(true)
              .width("100%")
              .height(42)
              .fontSize(14)
              .fontColor($r("app.color.primary_font_color"))
              .placeholderColor($r("app.color.input_placeholder"))
              .backgroundColor($r("app.color.card_sub_bg"))
              .borderRadius(10)
              .padding({ left: 12, right: 12 })
              .onChange((value: string) => {
                this.draftApiKey = value
              })
            Text('Key 只保存在本机的应用数据中')
              .width("100%")
              .fontSize(11)
              .fontColor($r("app.color.text_secondary"))
          }
          .width("100%")

          Column({ space: 6 }) {
            Text('模型')
              .width("100%")
              .fontSize(12)
              .fontColor($r("app.color.text_secondary"))
            TextInput({ text: this.draftModel, placeholder: 'deepseek-chat' })
              .width("100%")
              .height(42)
              .fontSize(14)
              .fontColor($r("app.color.primary_font_color"))
              .placeholderColor($r("app.color.input_placeholder"))
              .backgroundColor($r("app.color.card_sub_bg"))
              .borderRadius(10)
              .padding({ left: 12, right: 12 })
              .onChange((value: string) => {
                this.draftModel = value
              })
          }
          .width("100%")

          Column({ space: 6 }) {
            Text('上下文消息数')
              .width("100%")
              .fontSize(12)
              .fontColor($r("app.color.text_secondary"))
            TextInput({ text: this.draftContext, placeholder: '40' })
              .type(InputType.Number)
              .width("100%")
              .height(42)
              .fontSize(14)
              .fontColor($r("app.color.primary_font_color"))
              .placeholderColor($r("app.color.input_placeholder"))
              .backgroundColor($r("app.color.card_sub_bg"))
              .borderRadius(10)
              .padding({ left: 12, right: 12 })
              .onChange((value: string) => {
                this.draftContext = value
              })
            Text('每次请求携带的最近消息条数（2-200），越大上下文越完整、消耗也越大')
              .width("100%")
              .fontSize(11)
              .fontColor($r("app.color.text_secondary"))
          }
          .width("100%")

          Column({ space: 6 }) {
            Text('最大回复 tokens')
              .width("100%")
              .fontSize(12)
              .fontColor($r("app.color.text_secondary"))
            TextInput({ text: this.draftMaxTokens, placeholder: '4096' })
              .type(InputType.Number)
              .width("100%")
              .height(42)
              .fontSize(14)
              .fontColor($r("app.color.primary_font_color"))
              .placeholderColor($r("app.color.input_placeholder"))
              .backgroundColor($r("app.color.card_sub_bg"))
              .borderRadius(10)
              .padding({ left: 12, right: 12 })
              .onChange((value: string) => {
                this.draftMaxTokens = value
              })
            Text('0 表示使用服务端默认值；DeepSeek 最大 8192')
              .width("100%")
              .fontSize(11)
              .fontColor($r("app.color.text_secondary"))
          }
          .width("100%")

          if (this.editingId.length > 0 && this.settings.profiles.length > 1) {
            Button('删除这套配置')
              .width("100%")
              .height(38)
              .fontSize(13)
              .fontColor($r("app.color.error_text"))
              .backgroundColor(Color.Transparent)
              .margin({ top: 4 })
              .onClick(() => this.deleteCurrent())
          }
        }
        .width("100%")
      }
      .width("100%")
      .constraintSize({ maxHeight: 380 })
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width("100%")
  }
}
