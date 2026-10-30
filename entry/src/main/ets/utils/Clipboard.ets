import { pasteboard } from '@kit.BasicServicesKit'
import { ChatMessage, ChatRole } from '../model/ChatMessage'
import { Conversation } from '../model/Conversation'

/** 把整个会话格式化成可复制的纯文本 */
export function formatConversationText(conversation: Conversation): string {
  const lines: string[] = []
  for (const message of conversation.messages) {
    const content = message.content.trim()
    if (content.length === 0) {
      continue
    }
    const speaker = message.role === ChatRole.USER ? '你' : 'AI'
    lines.push(`${speaker}：${content}`)
  }
  return lines.join('\n\n')
}

/** 会话中最后一条用户消息，没有则返回 null */
export function findLastUserMessage(conversation: Conversation): ChatMessage | null {
  for (let i = conversation.messages.length - 1; i >= 0; i--) {
    if (conversation.messages[i].role === ChatRole.USER) {
      return conversation.messages[i]
    }
  }
  return null
}

/** 复制文本到系统剪贴板 */
export async function copyTextToClipboard(text: string): Promise<boolean> {
  try {
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text)
    const board = pasteboard.getSystemPasteboard()
    await board.setData(data)
    return true
  } catch (e) {
    return false
  }
}
