import { ChatStore, useChat } from '../store/useChat'
import { ConversationActionStore, useConversationActions } from '../store/useConversationActions'
import { copyTextToClipboard, findLastUserMessage } from '../utils/Clipboard'

/**
 * 点击「用户消息」后弹出的操作菜单。
 * 2 秒内没有任何操作会自动关闭（由 ConversationActionStore 计时）。
 */
@ComponentV2
export default struct MessageMenuDialog {
  chat: ChatStore = useChat()
  actions: ConversationActionStore = useConversationActions()

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

  private close(): void {
    this.actions.closeMessageMenu()
  }

  private async copyMessage(): Promise<void> {
    const text = this.actions.messageMenuContent
    this.close()
    const ok = await copyTextToClipboard(text)
    this.toast(ok ? '已复制消息' : '复制失败')
  }

  private editMessage(): void {
    const conversation = this.chat.getConversation(this.actions.messageMenuConversationId)
    if (conversation === null) {
      this.close()
      return
    }
    const lastUser = findLastUserMessage(conversation)
    if (lastUser === null || lastUser.id !== this.actions.messageMenuMessageId) {
      this.close()
      this.toast('只能修改最后一条用户消息')
      return
    }
    const content = lastUser.content
    const conversationId = conversation.id
    this.close()
    this.actions.openEdit(conversationId, content)
  }

  private deleteMessage(): void {
    const removed = this.chat.deleteMessage(this.actions.messageMenuConversationId,
      this.actions.messageMenuMessageId)
    this.close()
    this.toast(removed ? '已删除该消息及之后的内容' : '删除失败')
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 轻遮罩，点击空白关闭
      Column()
        .width("100%")
        .height("100%")
        .backgroundColor('#33000000')
        .onClick(() => this.close())

      Column() {
        Text('消息操作')
          .width("100%")
          .fontSize(12)
          .fontColor($r("app.color.text_secondary"))
          .margin({ bottom: 8 })

        Column() {
          this.buildAction('复制', () => {
            this.copyMessage()
          })
          Divider()
            .strokeWidth(0.5)
            .color($r("app.color.divider_color"))
          this.buildAction('修改', () => {
            this.editMessage()
          })
          Divider()
            .strokeWidth(0.5)
            .color($r("app.color.divider_color"))
          this.buildAction('删除', () => {
            this.deleteMessage()
          })
        }
        .width("100%")
        .backgroundColor($r("app.color.card_sub_bg"))
        .borderRadius(14)
        .clip(true)
      }
      .width("62%")
      .constraintSize({ maxWidth: 300 })
      .padding(16)
      .backgroundColor($r("app.color.card_bg"))
      .borderRadius(20)
      .clip(true)
      .shadow({ radius: 26, color: '#33000000', offsetX: 0, offsetY: 10 })
    }
    .width("100%")
    .height("100%")
  }

  @Builder
  buildAction(label: string, action: () => void) {
    Text(label)
      .width("100%")
      .textAlign(TextAlign.Center)
      .fontSize(15)
      .fontColor(label === '删除' ? $r("app.color.error_text") : $r("app.color.primary_font_color"))
      .padding({ top: 12, bottom: 12 })
      .onClick(() => action())
  }
}
