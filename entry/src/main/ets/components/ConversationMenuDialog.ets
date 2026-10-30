import { ChatStore, useChat } from '../store/useChat'
import { ConversationActionStore, useConversationActions } from '../store/useConversationActions'
import { copyTextToClipboard, findLastUserMessage, formatConversationText } from '../utils/Clipboard'

/**
 * 长按会话弹出的操作菜单：复制 / 修改 / 删除
 */
@ComponentV2
export default struct ConversationMenuDialog {
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
    this.actions.closeMenu()
  }

  private async copyConversation(): Promise<void> {
    const conversation = this.chat.getConversation(this.actions.menuConversationId)
    if (conversation === null) {
      this.close()
      return
    }
    const text = formatConversationText(conversation)
    if (text.length === 0) {
      this.toast('这个对话还没有内容')
      return
    }
    const ok = await copyTextToClipboard(text)
    this.close()
    this.toast(ok ? '已复制对话内容' : '复制失败')
  }

  private editLastMessage(): void {
    const conversation = this.chat.getConversation(this.actions.menuConversationId)
    if (conversation === null) {
      this.close()
      return
    }
    const lastUser = findLastUserMessage(conversation)
    if (lastUser === null) {
      this.toast('这个对话还没有用户消息，无法修改')
      return
    }
    this.close()
    this.actions.openEdit(conversation.id, lastUser.content)
  }

  private startDelete(): void {
    this.close()
    this.actions.enterSelection()
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width("100%")
        .height("100%")
        .backgroundColor('#66000000')
        .onClick(() => {
          // 长按松手会在弹窗刚出现时触发一次点击，短暂保护期内忽略
          if (this.actions.isMenuJustOpened()) {
            return
          }
          this.close()
        })

      Column() {
        Text(this.actions.menuConversationTitle.length > 0 ?
          this.actions.menuConversationTitle : '对话操作')
          .width("100%")
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r("app.color.primary_font_color"))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ bottom: 12 })

        Column() {
          this.buildAction('复制', '把整个对话复制到剪贴板', false, () => {
            this.copyConversation()
          })
          Divider()
            .strokeWidth(0.5)
            .color($r("app.color.divider_color"))
          this.buildAction('修改', '修改最后一条用户消息并重新生成', false, () => {
            this.editLastMessage()
          })
          Divider()
            .strokeWidth(0.5)
            .color($r("app.color.divider_color"))
          this.buildAction('删除', '多选对话并批量删除', true, () => {
            this.startDelete()
          })
        }
        .width("100%")
        .backgroundColor($r("app.color.card_sub_bg"))
        .borderRadius(14)
        .clip(true)

        Button('取消')
          .width("100%")
          .height(42)
          .fontSize(14)
          .fontColor($r("app.color.primary_font_color"))
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: $r("app.color.card_border") })
          .borderRadius(21)
          .margin({ top: 14 })
          .onClick(() => this.close())
      }
      .width("86%")
      .constraintSize({ maxWidth: 400 })
      .padding(20)
      .backgroundColor($r("app.color.card_bg"))
      .borderRadius(22)
      .clip(true)
      .shadow({ radius: 30, color: '#33000000', offsetX: 0, offsetY: 12 })
    }
    .width("100%")
    .height("100%")
  }

  @Builder
  buildAction(label: string, description: string, danger: boolean, action: () => void) {
    Column({ space: 3 }) {
      Text(label)
        .width("100%")
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(danger ? $r("app.color.error_text") : $r("app.color.primary_font_color"))
      Text(description)
        .width("100%")
        .fontSize(11)
        .fontColor($r("app.color.text_secondary"))
    }
    .width("100%")
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 14, right: 14, top: 11, bottom: 11 })
    .onClick(() => action())
  }
}
