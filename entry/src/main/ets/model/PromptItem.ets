/**
 * 一条提示词（系统提示词或常用提示词）
 */
@ObservedV2
export class PromptItem {
  private static seq: number = 0

  @Trace id: string = ''
  /** 显示名称，留空时自动取自内容 */
  @Trace name: string = ''
  /** 提示词正文 */
  @Trace content: string = ''

  constructor(name: string, content: string) {
    PromptItem.seq += 1
    this.id = `${Date.now()}-${PromptItem.seq}`
    this.name = name
    this.content = content
  }

  static restore(name: string, content: string, id: string): PromptItem {
    const item = new PromptItem(name, content)
    if (id.length > 0) {
      item.id = id
    }
    return item
  }

  get displayName(): string {
    if (this.name.trim().length > 0) {
      return this.name.trim()
    }
    const oneLine = this.content.split('\n').join(' ').trim()
    return oneLine.length > 16 ? `${oneLine.substring(0, 16)}…` : oneLine
  }

  get preview(): string {
    const oneLine = this.content.split('\n').join(' ').trim()
    return oneLine.length > 60 ? `${oneLine.substring(0, 60)}…` : oneLine
  }

  copyFrom(other: PromptItem): void {
    this.name = other.name
    this.content = other.content
  }
}
