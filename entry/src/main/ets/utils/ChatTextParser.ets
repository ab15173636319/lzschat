/**
 * 聊天文本解析：把括号里的说明/旁白文字拆成独立片段，
 * 由气泡组件分别用小字、浅色、斜体渲染。
 *
 * 支持半角 () 与全角 （），例如：
 *   “（轻轻笑了笑）今天天气不错。” → [旁白:轻轻笑了笑, 正文:今天天气不错。]
 */
export class ChatTextSegment {
  /** true = 括号内的说明文字（旁白） */
  isNote: boolean
  text: string

  constructor(isNote: boolean, text: string) {
    this.isNote = isNote
    this.text = text
  }
}

function findClosing(content: string, start: number): number {
  for (let i = start; i < content.length; i++) {
    const ch = content.charAt(i)
    if (ch === ')' || ch === '）') {
      return i
    }
  }
  return -1
}

/**
 * 解析一条消息文本为若干片段。
 * 未闭合的括号（流式输出过程中很常见）暂时按正文显示，闭合后再变成旁白。
 */
export function parseChatText(content: string): ChatTextSegment[] {
  const segments: ChatTextSegment[] = []
  if (content.length === 0) {
    return segments
  }
  let buffer = ''
  let index = 0
  while (index < content.length) {
    const ch = content.charAt(index)
    if (ch === '(' || ch === '（') {
      const closing = findClosing(content, index + 1)
      if (closing < 0) {
        // 还没输出到右括号，先把剩下的当正文
        buffer += content.substring(index)
        index = content.length
        break
      }
      const outer = buffer.trim()
      if (outer.length > 0) {
        segments.push(new ChatTextSegment(false, outer))
      }
      buffer = ''
      const inner = content.substring(index + 1, closing).trim()
      if (inner.length > 0) {
        segments.push(new ChatTextSegment(true, inner))
      }
      index = closing + 1
    } else {
      buffer += ch
      index += 1
    }
  }
  const rest = buffer.trim()
  if (rest.length > 0) {
    segments.push(new ChatTextSegment(false, rest))
  }
  return segments
}
