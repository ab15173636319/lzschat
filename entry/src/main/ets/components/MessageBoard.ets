import MessageBubble from './MessageBubble'
import { AiSettings, useAiSettings } from '../model/AiSettings'
import { ChatMessage } from '../model/ChatMessage'
import { PromptItem } from '../model/PromptItem'
import { PromptSettings, usePromptSettings } from '../model/PromptSettings'
import { ChatStore, useChat } from '../store/useChat'
import { ModelDialogState, useModelDialog } from '../store/useModelDialog'

/**
 * 消息列表：空态引导 + 气泡列表 + 自动滚动
 */
@ComponentV2
export default struct MessageBoard {
  @Local chat: ChatStore = useChat()
  settings: AiSettings = useAiSettings()
  prompts: PromptSettings = usePromptSettings()
  dialog: ModelDialogState = useModelDialog()
  private scroller: Scroller = new Scroller()

  get configReady(): boolean {
    const active = this.settings.active
    return active !== null && active.isReady
  }

  get activeModelLabel(): string {
    const active = this.settings.active
    if (active === null) {
      return '未选择模型'
    }
    return active.displayModel
  }

  aboutToAppear(): void {
    this.scrollToBottom()
  }

  // 每次流式内容变化都滚到底部（tick 由 store 维护）
  @Monitor('chat.tick')
  onContentChanged(): void {
    this.scrollToBottom()
  }

  private scrollToBottom(): void {
    setTimeout(() => {
      try {
        this.scroller.scrollEdge(Edge.Bottom)
      } catch (e) {
        // 列表尚未挂载时忽略
      }
    }, 30)
  }

  build() {
    Column() {
      if (!this.chat.hasMessages) {
        this.buildEmptyState()
      } else {
        List({ space: 14, scroller: this.scroller }) {
          ForEach(this.chat.messages, (message: ChatMessage) => {
            ListItem() {
              MessageBubble({ message: message })
            }
          }, (message: ChatMessage) => message.id)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .padding({ left: 2, right: 2, top: 10, bottom: 10 })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  buildEmptyState() {
    Column({ space: 14 }) {
      Stack() {
        Text('AI')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.start_window_background'))
      }
      .width(68)
      .height(68)
      .borderRadius(22)
      .backgroundColor($r('app.color.primary_font_color'))
      .margin({ bottom: 6 })

      Text('有什么可以帮你的？')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.primary_font_color'))

      Text(this.configReady ?
        `当前模型：${this.activeModelLabel}` : '还没有配置模型，先设置接口地址和 API Key 吧')
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)

      if (!this.configReady) {
        Button('去配置')
          .fontSize(14)
          .fontColor($r('app.color.start_window_background'))
          .backgroundColor($r('app.color.primary_font_color'))
          .height(36)
          .borderRadius(18)
          .padding({ left: 20, right: 20 })
          .margin({ top: 8 })
          .onClick(() => {
            this.dialog.open()
          })
      } else {
        Scroll() {
          Column({ space: 10 }) {
            ForEach(this.prompts.userPrompts, (item: PromptItem) => {
              Button(item.displayName)
                .type(ButtonType.Normal)
                .fontSize(14)
                .fontColor($r('app.color.primary_font_color'))
                .backgroundColor($r('app.color.card_bg'))
                .border({ width: 1, color: $r('app.color.card_border') })
                .borderRadius(16)
                .width('100%')
                .height(44)
                .padding({ left: 14, right: 14 })
                .labelStyle({ maxLines: 1, overflow: TextOverflow.Ellipsis })
                .onClick(() => {
                  this.chat.sendText(item.content)
                })
            }, (item: PromptItem) => `${item.id}-${item.name}-${item.content}`)
          }
          .width('100%')
        }
        .width('100%')
        .constraintSize({ maxHeight: 280 })
        .scrollBar(BarState.Off)
        .margin({ top: 10 })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ left: 20, right: 20, bottom: 30 })
  }
}
