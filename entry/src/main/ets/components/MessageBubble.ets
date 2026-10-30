import { ChatMessage, ChatRole, MessageStatus } from '../model/ChatMessage'
import { PromptSettings, usePromptSettings } from '../model/PromptSettings'
import { ChatStore, useChat } from '../store/useChat'
import { ConversationActionStore, useConversationActions } from '../store/useConversationActions'
import { ChatTextSegment, parseChatText } from '../utils/ChatTextParser'

/**
 * 单条消息气泡（角色名 + 竖线 + 对白 + 括号旁白）
 *
 * - 用户消息：靠右，金色「你」标签 + 右侧强调竖线；点击弹出消息菜单
 * - AI 消息：靠左，角色名 + 左侧竖线；括号 ()/（）里的说明文字单独成行，
 *   用小字、浅色、斜体展示，与正文区分
 */
@ComponentV2
export default struct MessageBubble {
  @Param message: ChatMessage = new ChatMessage(ChatRole.ASSISTANT, '')
  chat: ChatStore = useChat()
  prompts: PromptSettings = usePromptSettings()
  actions: ConversationActionStore = useConversationActions()

  private assistantLabel(): string {
    const name = this.prompts.activeSystemName
    if (name.length === 0 || name === '默认提示词') {
      return 'AI'
    }
    return name
  }

  /** 点击用户消息：呼出复制/修改/删除菜单（2 秒无操作自动关闭） */
  private openMessageMenu(): void {
    const conversationId = this.chat.activeId
    if (conversationId.length === 0) {
      return
    }
    this.actions.openMessageMenu(conversationId, this.message.id, this.message.content)
  }

  /** 解析消息内容；流式输出时在最后一个片段末尾补光标 */
  private buildSegmentsList(): ChatTextSegment[] {
    const segments = parseChatText(this.message.content)
    if (this.message.status === MessageStatus.STREAMING) {
      if (segments.length === 0) {
        segments.push(new ChatTextSegment(false, '▍'))
      } else {
        const last = segments[segments.length - 1]
        last.text = `${last.text} ▍`
      }
    }
    return segments
  }

  build() {
    if (this.message.role === ChatRole.USER) {
      this.buildUserBubble()
    } else {
      this.buildAssistantBubble()
    }
  }

  @Builder
  buildUserBubble() {
    Column({ space: 4 }) {
      Text('你')
        .fontSize(11)
        .fontColor($r('app.color.role_accent'))

      Text(this.message.content)
        .fontSize(15)
        .lineHeight(23)
        .fontColor($r('app.color.primary_font_color'))
        .textSelectable(TextSelectableMode.UNSELECTABLE)
        .constraintSize({ maxWidth: '82%' })
        .padding({ right: 10, top: 1, bottom: 1 })
        .border({ width: { right: 2 }, color: $r('app.color.role_accent') })
        .onClick(() => {
          this.openMessageMenu()
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.End)
  }

  @Builder
  buildAssistantBubble() {
    Row() {
      Column({ space: 6 }) {
        Text(this.assistantLabel())
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))

        if (this.message.status === MessageStatus.ERROR) {
          if (this.message.content.length > 0) {
            this.buildContent()
          }
          Text(this.message.error.length > 0 ? this.message.error : '请求失败，请重试')
            .fontSize(13)
            .lineHeight(19)
            .fontColor($r('app.color.error_text'))
          Button('重试')
            .fontSize(13)
            .fontColor($r('app.color.primary_font_color'))
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: $r('app.color.divider_color') })
            .borderRadius(14)
            .height(28)
            .padding({ left: 12, right: 12 })
            .onClick(() => {
              this.chat.retry()
            })
        } else if (this.message.status === MessageStatus.STREAMING && this.message.content.length === 0) {
          Row({ space: 6 }) {
            LoadingProgress()
              .width(14)
              .height(14)
              .color($r('app.color.text_secondary'))
            Text('正在思考…')
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          }
        } else {
          this.buildContent()
          if (this.message.status === MessageStatus.STOPPED) {
            Text('已停止生成')
              .fontSize(11)
              .fontColor($r('app.color.text_secondary'))
          }
        }
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 10, top: 1, bottom: 1 })
      .border({
        width: { left: 2 },
        color: this.message.status === MessageStatus.ERROR ?
          $r('app.color.error_text') : $r('app.color.ai_line')
      })
      .constraintSize({ maxWidth: '88%' })
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .alignItems(VerticalAlign.Top)
  }

  /** 正文 + 括号旁白分段渲染 */
  @Builder
  buildContent() {
    ForEach(this.buildSegmentsList(), (segment: ChatTextSegment) => {
      if (segment.isNote) {
        Text(segment.text)
          .fontSize(12)
          .lineHeight(18)
          .fontColor($r('app.color.note_text'))
          .fontStyle(FontStyle.Italic)
          .padding({ top: 1, bottom: 1 })
      } else {
        Text(segment.text)
          .fontSize(15)
          .lineHeight(23)
          .fontColor($r('app.color.primary_font_color'))
          .copyOption(CopyOptions.LocalDevice)
      }
    }, (segment: ChatTextSegment, index: number) =>
      `${index}-${segment.isNote ? 'n' : 't'}-${segment.text}`)
  }
}
