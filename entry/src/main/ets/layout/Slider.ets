import { AiSettings, useAiSettings } from '../model/AiSettings'
import { Conversation } from '../model/Conversation'
import { ModelProfile } from '../model/ModelProfile'
import { PromptSettings, usePromptSettings } from '../model/PromptSettings'
import { BalanceStore, useBalance } from '../store/useBalance'
import { ChatStore, useChat } from '../store/useChat'
import { ConversationActionStore, useConversationActions } from '../store/useConversationActions'
import { ModelDialogState, useModelDialog } from '../store/useModelDialog'
import { PromptDialogState, usePromptDialog } from '../store/usePromptDialog'
import { SafeArea, useSafeArea } from '../store/useSafeArea'
import { Slider, useSlider } from '../store/useSlider'

/**
 * 侧边栏：会话列表 + 当前模型 + 提示词
 */
@ComponentV2
export default struct SliderBar {
  settings: AiSettings = useAiSettings()
  prompts: PromptSettings = usePromptSettings()
  balance: BalanceStore = useBalance()
  chat: ChatStore = useChat()
  actions: ConversationActionStore = useConversationActions()
  dialog: ModelDialogState = useModelDialog()
  promptDialog: PromptDialogState = usePromptDialog()
  slider: Slider = useSlider()
  safeArea: SafeArea = useSafeArea()

  // 手动长按检测（不依赖手势仲裁，避免被 Scroll/文本选择抢占）
  private pressTimer: number = -1
  private pressStartX: number = 0
  private pressStartY: number = 0
  private pressConversation: Conversation | null = null

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message,
        duration: 1500
      })
    } catch (e) {
      // 页面未挂载时忽略
    }
  }

  private closeDrawer(): void {
    this.actions.cancelSelection()
    this.slider.close()
  }

  private deleteSelected(): void {
    const ids = this.actions.selectedIds.slice()
    if (ids.length === 0) {
      this.toast('请先勾选要删除的对话')
      return
    }
    const removed = this.chat.deleteConversations(ids)
    this.actions.cancelSelection()
    this.toast(removed > 0 ? `已删除 ${removed} 个对话` : '没有删除任何对话')
  }

  private openConversationMenu(conversation: Conversation): void {
    if (this.actions.selecting) {
      return
    }
    this.actions.markLongPress()
    this.actions.openMenu(conversation.id, conversation.titleOrDefault)
  }

  private handleRowTouch(conversation: Conversation, event: TouchEvent): void {
    if (event.type === TouchType.Down) {
      this.startLongPress(conversation, event)
      return
    }
    if (event.type === TouchType.Move) {
      this.checkLongPressMove(event)
      return
    }
    this.cancelLongPress()
  }

  private startLongPress(conversation: Conversation, event: TouchEvent): void {
    if (this.actions.selecting || event.touches.length !== 1) {
      return
    }
    this.cancelLongPress()
    this.pressStartX = event.touches[0].x
    this.pressStartY = event.touches[0].y
    this.pressConversation = conversation
    this.pressTimer = setTimeout(() => {
      this.pressTimer = -1
      const target = this.pressConversation
      this.pressConversation = null
      if (target !== null && !this.actions.selecting) {
        this.openConversationMenu(target)
      }
    }, 450)
  }

  /** 手指移动超过 15vp 认为是在滚动列表，取消长按 */
  private checkLongPressMove(event: TouchEvent): void {
    if (this.pressTimer < 0 || event.touches.length === 0) {
      return
    }
    const dx = event.touches[0].x - this.pressStartX
    const dy = event.touches[0].y - this.pressStartY
    if (dx * dx + dy * dy > 225) {
      this.cancelLongPress()
    }
  }

  private cancelLongPress(): void {
    if (this.pressTimer >= 0) {
      clearTimeout(this.pressTimer)
      this.pressTimer = -1
    }
    this.pressConversation = null
  }

  private activeProfile(): ModelProfile | null {
    return this.settings.active
  }

  private modelTitle(): string {
    const profile = this.activeProfile()
    if (profile === null) {
      return '未配置模型'
    }
    return profile.name.trim().length > 0 ? profile.name : '未命名模型'
  }

  private modelSubtitle(): string {
    const profile = this.activeProfile()
    if (profile === null) {
      return '点击下方按钮添加模型配置'
    }
    return `${profile.displayModel} · ${profile.baseUrl}`
  }

  private modelReady(): boolean {
    const profile = this.activeProfile()
    return profile !== null && profile.isReady
  }

  private balanceText(): string {
    const profile = this.activeProfile()
    if (profile !== null && this.balance.isFor(profile.id) && this.balance.summary.length > 0) {
      return `余额 ${this.balance.summary}`
    }
    return ''
  }

  private modelMeta(): string {
    const profile = this.activeProfile()
    if (profile === null) {
      return ''
    }
    const maxTokens = profile.resolveMaxTokens()
    return `上下文 ${profile.resolveContextMessages()} 条 · 回复上限 ${maxTokens === 0 ? '默认' : maxTokens + ' tokens'}`
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('对话')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r("app.color.primary_font_color"))

        Blank()

        Button({ stateEffect: false }) {
          Text('×')
            .fontSize(26)
            .fontColor($r("app.color.primary_font_color"))
        }
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .onClick(() => this.closeDrawer())
      }
      .width("100%")
      .height(52)
      .padding({ left: 16, right: 8 })

      Scroll() {
        Column({ space: 16 }) {
          // ---------- 会话列表 ----------
          Row() {
            Text('全部对话')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r("app.color.text_secondary"))

            Blank()

            Text(`${this.chat.conversations.length} 个`)
              .fontSize(11)
              .fontColor($r("app.color.text_secondary"))
          }
          .width("100%")

          Button('+ 新建对话')
            .width("100%")
            .height(40)
            .fontSize(14)
            .fontColor($r("app.color.start_window_background"))
            .backgroundColor($r("app.color.primary_font_color"))
            .borderRadius(20)
            .onClick(() => {
              this.actions.cancelSelection()
              this.chat.newChat()
              this.slider.close()
            })

          Column({ space: 6 }) {
            ForEach(this.chat.conversations, (conversation: Conversation) => {
              Row({ space: 6 }) {
                if (this.actions.selecting) {
                  Stack() {
                    Row()
                      .width(18)
                      .height(18)
                      .borderRadius(5)
                      .border({
                        width: 1.5,
                        color: this.actions.isSelected(conversation.id) ?
                          $r("app.color.primary_font_color") : $r("app.color.card_border")
                      })
                      .backgroundColor(this.actions.isSelected(conversation.id) ?
                        $r("app.color.primary_font_color") : Color.Transparent)
                    if (this.actions.isSelected(conversation.id)) {
                      Text('✓')
                        .fontSize(11)
                        .fontColor($r("app.color.start_window_background"))
                        .textSelectable(TextSelectableMode.UNSELECTABLE)
                        .hitTestBehavior(HitTestMode.None)
                    }
                  }
                  .width(18)
                  .height(18)
                }

                Column({ space: 3 }) {
                  Row({ space: 6 }) {
                    Text(conversation.titleOrDefault)
                      .layoutWeight(1)
                      .fontSize(13)
                      .fontWeight(this.chat.activeId === conversation.id ?
                        FontWeight.Medium : FontWeight.Normal)
                      .fontColor($r("app.color.primary_font_color"))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .textSelectable(TextSelectableMode.UNSELECTABLE)
                      .hitTestBehavior(HitTestMode.None)
                    Text(conversation.timeLabel)
                      .fontSize(10)
                      .fontColor($r("app.color.text_secondary"))
                      .textSelectable(TextSelectableMode.UNSELECTABLE)
                      .hitTestBehavior(HitTestMode.None)
                  }
                  .width("100%")

                  Text(conversation.preview)
                    .width("100%")
                    .fontSize(11)
                    .fontColor($r("app.color.text_secondary"))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .textSelectable(TextSelectableMode.UNSELECTABLE)
                    .hitTestBehavior(HitTestMode.None)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width("100%")
              .padding({ left: 12, right: 6, top: 9, bottom: 9 })
              .borderRadius(12)
              .backgroundColor(this.actions.selecting && this.actions.isSelected(conversation.id) ?
                $r("app.color.card_sub_bg") : (this.chat.activeId === conversation.id ?
                  $r("app.color.card_sub_bg") : Color.Transparent))
              .border({
                width: 1,
                color: (this.chat.activeId === conversation.id || this.actions.isSelected(conversation.id)) ?
                  $r("app.color.card_border") : Color.Transparent
              })
              .hitTestBehavior(HitTestMode.Block)
              .onTouch((event: TouchEvent) => {
                this.handleRowTouch(conversation, event)
              })
              .gesture(
                // 备用触发：手动计时器之外再保留系统长按手势
                LongPressGesture({ repeat: false, duration: 450 })
                  .onAction(() => {
                    this.openConversationMenu(conversation)
                  })
              )
              .onClick(() => {
                if (this.actions.selecting) {
                  this.actions.toggle(conversation.id)
                  return
                }
                if (this.actions.wasJustLongPressed() || this.actions.menuVisible) {
                  return
                }
                this.chat.switchTo(conversation.id)
                this.slider.close()
              })
            }, (conversation: Conversation) =>
              `${conversation.id}-${conversation.updatedAt}-${conversation.title}-${this.chat.activeId === conversation.id ? '1' : '0'}-${this.actions.selecting ? '1' : '0'}-${this.actions.isSelected(conversation.id) ? '1' : '0'}`)
          }
          .width("100%")

          // ---------- 模型 ----------
          Text('模型')
            .width("100%")
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r("app.color.text_secondary"))

          Column({ space: 12 }) {
            Row() {
              Column({ space: 4 }) {
                Row({ space: 6 }) {
                  Text(this.modelTitle())
                    .fontSize(14)
                    .fontColor($r("app.color.primary_font_color"))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .constraintSize({ maxWidth: '60%' })
                  if (!this.modelReady()) {
                    Text('未配置 Key')
                      .fontSize(10)
                      .fontColor($r("app.color.error_text"))
                      .backgroundColor($r("app.color.error_bg"))
                      .borderRadius(4)
                      .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                  }
                }

                Text(this.modelSubtitle())
                  .fontSize(11)
                  .fontColor($r("app.color.text_secondary"))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(this.modelMeta())
                  .fontSize(11)
                  .fontColor($r("app.color.text_secondary"))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                if (this.balanceText().length > 0) {
                  Text(this.balanceText())
                    .fontSize(11)
                    .fontColor($r("app.color.text_secondary"))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width("100%")

            Button('模型配置')
              .width("100%")
              .height(40)
              .fontSize(14)
              .fontColor($r("app.color.primary_font_color"))
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: $r("app.color.card_border") })
              .borderRadius(20)
              .onClick(() => {
                this.actions.cancelSelection()
                this.dialog.open()
                this.slider.close()
              })
          }
          .width("100%")
          .padding(14)
          .backgroundColor($r("app.color.card_bg"))
          .borderRadius(16)
          .border({ width: 1, color: $r("app.color.card_border") })

          // ---------- 提示词 ----------
          Text('提示词')
            .width("100%")
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r("app.color.text_secondary"))

          Column({ space: 12 }) {
            Row() {
              Column({ space: 4 }) {
                Row({ space: 6 }) {
                  Text(this.prompts.activeSystemName)
                    .fontSize(14)
                    .fontColor($r("app.color.primary_font_color"))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .constraintSize({ maxWidth: '70%' })
                  Text('系统')
                    .fontSize(10)
                    .fontColor($r("app.color.text_secondary"))
                    .backgroundColor($r("app.color.card_sub_bg"))
                    .borderRadius(4)
                    .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                }

                Text(`${this.prompts.userPrompts.length} 条常用提示词`)
                  .fontSize(11)
                  .fontColor($r("app.color.text_secondary"))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width("100%")

            Button('提示词设置')
              .width("100%")
              .height(40)
              .fontSize(14)
              .fontColor($r("app.color.primary_font_color"))
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: $r("app.color.card_border") })
              .borderRadius(20)
              .onClick(() => {
                this.actions.cancelSelection()
                this.promptDialog.open()
                this.slider.close()
              })
          }
          .width("100%")
          .padding(14)
          .backgroundColor($r("app.color.card_bg"))
          .borderRadius(16)
          .border({ width: 1, color: $r("app.color.card_border") })

          Text('对话与消息保存在本机（最多 30 个对话、每个对话最近 500 条消息）')
            .width("100%")
            .fontSize(11)
            .lineHeight(17)
            .fontColor($r("app.color.text_secondary"))
        }
        .width("100%")
        .padding({ left: 16, right: 16, bottom: this.safeArea.bottom + 24 })
      }
      .width("100%")
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // 多选删除模式：底部输入区替换为「取消 / 删除」
      if (this.actions.selecting) {
        Column({ space: 8 }) {
          Text(this.actions.selectedCount() > 0 ?
            `已选 ${this.actions.selectedCount()} 个对话` : '勾选要删除的对话')
            .width("100%")
            .fontSize(11)
            .fontColor($r("app.color.text_secondary"))
            .textAlign(TextAlign.Center)

          Row({ space: 10 }) {
            Button('取消')
              .layoutWeight(1)
              .height(42)
              .fontSize(14)
              .fontColor($r("app.color.primary_font_color"))
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: $r("app.color.card_border") })
              .borderRadius(21)
              .onClick(() => this.actions.cancelSelection())

            Button(this.actions.selectedCount() > 0 ? `删除 (${this.actions.selectedCount()})` : '删除')
              .layoutWeight(1)
              .height(42)
              .fontSize(14)
              .fontColor($r("app.color.start_window_background"))
              .backgroundColor($r("app.color.error_text"))
              .borderRadius(21)
              .onClick(() => this.deleteSelected())
          }
          .width("100%")
        }
        .width("100%")
        .padding({ left: 16, right: 16, top: 10, bottom: this.safeArea.bottom + 10 })
        .backgroundColor($r("app.color.slider_bg"))
        .border({ width: { top: 0.5 }, color: $r("app.color.divider_color") })
      }
    }
    .width("100%")
    .height("100%")
    .padding({ top: this.safeArea.top })
    .backgroundColor($r("app.color.slider_bg"))
    .borderRadius({ topRight: 24, bottomRight: 24 })
    .clip(true)
  }
}
