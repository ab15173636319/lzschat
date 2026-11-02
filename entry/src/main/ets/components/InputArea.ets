import { AiSettings, useAiSettings } from '../model/AiSettings'
import { ChatStore, useChat } from '../store/useChat'
import { ModelDialogState, useModelDialog } from '../store/useModelDialog'

/**
 * 底部输入区
 */
@ComponentV2
export default struct InputArea {
  Send: Resource = $rawfile('assets/send.svg')
  chat: ChatStore = useChat()
  settings: AiSettings = useAiSettings()
  dialog: ModelDialogState = useModelDialog()

  @Local text: string = ''
  @Local focused: boolean = false

  get canSend(): boolean {
    return this.text.trim().length > 0 && !this.chat.isSending
  }

  private toast(message: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message: message,
        duration: 2000
      })
    } catch (e) {
      // 页面未挂载时忽略
    }
  }

  private send(): void {
    const content = this.text.trim()
    if (content.length === 0 || this.chat.isSending) {
      return
    }
    const active = this.settings.active
    if (active === null || !active.isReady) {
      this.dialog.open()
      this.toast('请先配置模型的接口地址与 API Key')
      return
    }
    this.text = ''
    this.chat.sendText(content)
  }

  build() {
    Column({ space: 8 }) {
      // 自动生成的 3 条历史相关选项
      if (!this.chat.isSending && this.chat.suggestedOptions.length > 0) {
        Row({ space: 6 }) {
          ForEach(this.chat.suggestedOptions, (option: string) => {
            Button(option)
              .layoutWeight(1)
              .height(34)
              .fontSize(12)
              .fontColor($r('app.color.primary_font_color'))
              .backgroundColor($r('app.color.card_bg'))
              .border({ width: 1, color: $r('app.color.card_border') })
              .borderRadius(17)
              .padding({ left: 6, right: 6 })
              .labelStyle({ maxLines: 1, overflow: TextOverflow.Ellipsis })
              .onClick(() => {
                this.chat.sendText(option)
              })
          }, (option: string, index: number) => `${index}-${option}`)
        }
        .width('100%')
      } else if (!this.chat.isSending && this.chat.optionsLoading) {
        Row({ space: 6 }) {
          LoadingProgress()
            .width(12)
            .height(12)
            .color($r('app.color.text_secondary'))
          Text('正在生成选项…')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .padding({ left: 4 })
      }

      Row({ space: 8 }) {
        TextArea({ text: this.text, placeholder: '发消息…' })
          .layoutWeight(1)
          .fontSize(15)
          .fontColor($r('app.color.primary_font_color'))
          .placeholderColor($r('app.color.input_placeholder'))
          .placeholderFont({ size: 15 })
          .caretColor($r('app.color.primary_font_color'))
          .backgroundColor(Color.Transparent)
          .padding({ left: 2, right: 2, top: 6, bottom: 6 })
          .maxLength(12000)
          .maxLines(4)
          .enterKeyType(EnterKeyType.Send)
          .onChange((value: string) => {
            this.text = value
          })
          .onFocus(() => {
            this.focused = true
          })
          .onBlur(() => {
            this.focused = false
          })
          .onSubmit(() => {
            this.send()
          })

        if (this.chat.isSending) {
          Button({ stateEffect: true }) {
            // 停止生成：方块图标（点击即停止）
            Row()
              .width(11)
              .height(11)
              .borderRadius(2)
              .backgroundColor($r('app.color.start_window_background'))
          }
          .width(38)
          .height(38)
          .borderRadius(19)
          .backgroundColor($r('app.color.primary_font_color'))
          .onClick(() => {
            this.chat.stop()
          })
        } else {
          Button({ stateEffect: true }) {
            Image(this.Send)
              .width(18)
              .height(18)
              .fillColor($r('app.color.start_window_background'))
          }
          .width(38)
          .height(38)
          .borderRadius(19)
          .backgroundColor(this.canSend ? $r('app.color.primary_font_color') : $r('app.color.send_disabled'))
          .onClick(() => {
            this.send()
          })
        }
      }
      .width('100%')
      .padding({ left: 12, right: 8, top: 6, bottom: 6 })
      .borderRadius(22)
      .backgroundColor($r('app.color.input_area_bg'))
      .border({
        width: 1,
        color: this.focused ? $r('app.color.primary_font_color') : $r('app.color.input_area_border')
      })
      .animation({ duration: 200, curve: Curve.EaseOut })
    }
    .width('100%')
  }
}
