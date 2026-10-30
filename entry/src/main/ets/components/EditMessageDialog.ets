import { ChatStore, useChat } from '../store/useChat'
import { ConversationActionStore, useConversationActions } from '../store/useConversationActions'
import { Slider, useSlider } from '../store/useSlider'

/**
 * 修改最后一条用户消息的弹窗。
 * 提交后丢弃该消息之后的回复，并重新生成。
 */
@ComponentV2
export default struct EditMessageDialog {
  chat: ChatStore = useChat()
  actions: ConversationActionStore = useConversationActions()
  slider: Slider = useSlider()

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
    this.actions.closeEdit()
  }

  private submit(): void {
    const content = this.actions.editText.trim()
    if (content.length === 0) {
      this.toast('消息内容不能为空')
      return
    }
    const conversationId = this.actions.editConversationId
    this.actions.closeEdit()
    const ok = this.chat.editLastUserMessage(conversationId, content)
    if (!ok) {
      this.toast('修改失败：没有找到可修改的用户消息')
      return
    }
    this.slider.close()
    this.toast('已修改，正在重新生成回复')
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width("100%")
        .height("100%")
        .backgroundColor('#66000000')
        .onClick(() => this.close())

      Column() {
        Text('修改消息')
          .width("100%")
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r("app.color.primary_font_color"))

        Text('只能修改这个对话最后一条用户消息，提交后会重新生成回复')
          .width("100%")
          .fontSize(11)
          .lineHeight(17)
          .fontColor($r("app.color.text_secondary"))
          .margin({ top: 6, bottom: 14 })

        TextArea({ text: this.actions.editText, placeholder: '输入要修改的内容…' })
          .width("100%")
          .height(140)
          .fontSize(14)
          .fontColor($r("app.color.primary_font_color"))
          .placeholderColor($r("app.color.input_placeholder"))
          .backgroundColor($r("app.color.card_sub_bg"))
          .borderRadius(10)
          .padding(12)
          .maxLength(12000)
          .onChange((value: string) => {
            this.actions.editText = value
          })

        Row({ space: 10 }) {
          Button('取消')
            .layoutWeight(1)
            .height(42)
            .fontSize(14)
            .fontColor($r("app.color.primary_font_color"))
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: $r("app.color.card_border") })
            .borderRadius(21)
            .onClick(() => this.close())

          Button('提交并重新生成')
            .layoutWeight(1)
            .height(42)
            .fontSize(14)
            .fontColor($r("app.color.start_window_background"))
            .backgroundColor($r("app.color.primary_font_color"))
            .borderRadius(21)
            .onClick(() => this.submit())
        }
        .width("100%")
        .margin({ top: 16 })
      }
      .width("88%")
      .constraintSize({ maxWidth: 440 })
      .padding(20)
      .backgroundColor($r("app.color.card_bg"))
      .borderRadius(22)
      .clip(true)
      .shadow({ radius: 30, color: '#33000000', offsetX: 0, offsetY: 12 })
    }
    .width("100%")
    .height("100%")
  }
}
