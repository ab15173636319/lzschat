import { PromptItem } from '../model/PromptItem'
import { PromptSettings, persistPrompts, usePromptSettings } from '../model/PromptSettings'
import { PromptDialogState, usePromptDialog } from '../store/usePromptDialog'

/**
 * 提示词弹窗
 *
 * - 系统提示词：可保存多套，点选一套作用于所有对话
 * - 常用提示词：新对话空态展示的快捷发送项，可保存多条
 */
@ComponentV2
export default struct PromptConfigDialog {
  settings: PromptSettings = usePromptSettings()
  dialog: PromptDialogState = usePromptDialog()

  /** 0 = 系统提示词，1 = 常用提示词 */
  @Local tab: number = 0
  @Local editing: boolean = false
  @Local editingType: number = 0
  @Local editingId: string = ''
  @Local draftName: string = ''
  @Local draftContent: string = ''

  aboutToAppear(): void {
    try {
      this.getUIContext().getFocusController().clearFocus()
    } catch (e) {
      // 忽略
    }
  }

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

  private autoName(content: string): string {
    const oneLine = content.split('\n').join(' ').trim()
    return oneLine.length > 16 ? `${oneLine.substring(0, 16)}…` : oneLine
  }

  private startCreate(type: number): void {
    this.editingType = type
    this.editingId = ''
    this.draftName = ''
    this.draftContent = ''
    this.editing = true
  }

  private startEdit(item: PromptItem, type: number): void {
    this.editingType = type
    this.editingId = item.id
    this.draftName = item.name
    this.draftContent = item.content
    this.editing = true
  }

  private selectSystem(item: PromptItem): void {
    this.settings.selectSystem(item.id)
    persistPrompts(this.settings)
    this.dialog.close()
    this.toast(`已切换系统提示词：${item.displayName}`)
  }

  private saveDraft(): void {
    const content = this.draftContent.trim()
    if (content.length === 0) {
      this.toast('提示词内容不能为空')
      return
    }
    const name = this.draftName.trim().length > 0 ? this.draftName.trim() : this.autoName(content)

    if (this.editingId.length === 0) {
      const item = new PromptItem(name, content)
      if (this.editingType === 0) {
        this.settings.addSystem(item)
        this.toast(`已添加系统提示词：${name}`)
      } else {
        this.settings.addUser(item)
        this.toast(`已添加常用提示词：${name}`)
      }
    } else {
      const existing = this.editingType === 0 ?
        this.settings.findSystem(this.editingId) : this.settings.findUser(this.editingId)
      if (existing === null) {
        this.toast('提示词不存在，请重新选择')
        return
      }
      existing.name = name
      existing.content = content
      if (this.editingType === 0) {
        this.settings.updateSystem(existing)
      } else {
        this.settings.updateUser(existing)
      }
      this.toast('提示词已保存')
    }
    persistPrompts(this.settings)
    this.dialog.close()
  }

  private deleteCurrent(): void {
    if (this.editingId.length === 0) {
      return
    }
    if (this.editingType === 0) {
      if (!this.settings.removeSystem(this.editingId)) {
        this.toast('至少保留一套系统提示词')
        return
      }
    } else {
      if (!this.settings.removeUser(this.editingId)) {
        return
      }
    }
    persistPrompts(this.settings)
    this.toast('已删除')
    this.dialog.close()
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 遮罩
      Column()
        .width("100%")
        .height("100%")
        .backgroundColor('#66000000')
        .onClick(() => this.dialog.close())

      // 弹窗卡片
      Column() {
        if (this.editing) {
          this.buildEditor()
        } else {
          this.buildList()
        }
      }
      .width("88%")
      .constraintSize({ maxWidth: 440, maxHeight: '82%' })
      .padding(20)
      .backgroundColor($r("app.color.card_bg"))
      .borderRadius(22)
      .clip(true)
      .shadow({ radius: 30, color: '#33000000', offsetX: 0, offsetY: 12 })
    }
    .width("100%")
    .height("100%")
  }

  // ---------------- 列表视图 ----------------

  @Builder
  buildList() {
    Column() {
      Row() {
        Text('提示词')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r("app.color.primary_font_color"))

        Blank()

        Button({ stateEffect: false }) {
          Text('×')
            .fontSize(24)
            .fontColor($r("app.color.text_secondary"))
        }
        .width(34)
        .height(34)
        .backgroundColor(Color.Transparent)
        .onClick(() => this.dialog.close())
      }
      .width("100%")
      .height(40)

      Row({ space: 8 }) {
        this.tabButton('系统提示词', 0)
        this.tabButton('常用提示词', 1)
      }
      .width("100%")
      .margin({ top: 4, bottom: 12 })

      Text(this.tab === 0 ?
        '保存多套系统提示词，点选一套作用于所有对话' :
        '新对话空态展示的快捷提示词，点击直接发送')
        .width("100%")
        .fontSize(12)
        .fontColor($r("app.color.text_secondary"))
        .margin({ bottom: 10 })

      Scroll() {
        Column({ space: 8 }) {
          if (this.tab === 0) {
            ForEach(this.settings.systemPrompts, (item: PromptItem) => {
              this.buildSystemRow(item)
            }, (item: PromptItem) =>
              `${item.id}-${item.name}-${item.content}-${this.settings.activeSystemId === item.id ? '1' : '0'}`)
          } else {
            ForEach(this.settings.userPrompts, (item: PromptItem) => {
              this.buildUserRow(item)
            }, (item: PromptItem) => `${item.id}-${item.name}-${item.content}`)
          }

          Button(this.tab === 0 ? '+ 新增系统提示词' : '+ 新增常用提示词')
            .width("100%")
            .height(42)
            .fontSize(14)
            .fontColor($r("app.color.primary_font_color"))
            .backgroundColor(Color.Transparent)
            .border({ width: 1, color: $r("app.color.card_border") })
            .borderRadius(21)
            .margin({ top: 6 })
            .onClick(() => this.startCreate(this.tab))
        }
        .width("100%")
      }
      .width("100%")
      .constraintSize({ maxHeight: 340 })
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width("100%")
  }

  @Builder
  tabButton(label: string, index: number) {
    Button(label)
      .type(ButtonType.Normal)
      .height(32)
      .fontSize(13)
      .fontColor(this.tab === index ?
        $r("app.color.start_window_background") : $r("app.color.text_secondary"))
      .backgroundColor(this.tab === index ?
        $r("app.color.primary_font_color") : $r("app.color.card_sub_bg"))
      .borderRadius(16)
      .padding({ left: 14, right: 14 })
      .onClick(() => {
        this.tab = index
      })
  }

  @Builder
  buildSystemRow(item: PromptItem) {
    Row({ space: 10 }) {
      Row({ space: 12 }) {
        // 单选指示器
        Stack() {
          Row()
            .width(18)
            .height(18)
            .borderRadius(9)
            .border({
              width: 1.5,
              color: this.settings.activeSystemId === item.id ?
                $r("app.color.primary_font_color") : $r("app.color.card_border")
            })
          if (this.settings.activeSystemId === item.id) {
            Row()
              .width(8)
              .height(8)
              .borderRadius(4)
              .backgroundColor($r("app.color.primary_font_color"))
          }
        }
        .width(18)
        .height(18)

        Column({ space: 3 }) {
          Text(item.displayName)
            .width("100%")
            .fontSize(14)
            .fontColor($r("app.color.primary_font_color"))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(item.preview)
            .width("100%")
            .fontSize(11)
            .fontColor($r("app.color.text_secondary"))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .onClick(() => this.selectSystem(item))

      Button('编辑')
        .fontSize(12)
        .fontColor($r("app.color.text_secondary"))
        .backgroundColor(Color.Transparent)
        .height(28)
        .padding({ left: 8, right: 8 })
        .onClick(() => this.startEdit(item, 0))
    }
    .width("100%")
    .padding({ left: 12, right: 8, top: 10, bottom: 10 })
    .borderRadius(14)
    .backgroundColor(this.settings.activeSystemId === item.id ?
      $r("app.color.card_sub_bg") : Color.Transparent)
  }

  @Builder
  buildUserRow(item: PromptItem) {
    Row({ space: 6 }) {
      Row({ space: 8 }) {
        Column({ space: 3 }) {
          Text(item.displayName)
            .width("100%")
            .fontSize(14)
            .fontColor($r("app.color.primary_font_color"))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(item.preview)
            .width("100%")
            .fontSize(11)
            .fontColor($r("app.color.text_secondary"))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .onClick(() => this.startEdit(item, 1))

      Button({ stateEffect: false }) {
        Text('×')
          .fontSize(16)
          .fontColor($r("app.color.text_secondary"))
      }
      .width(28)
      .height(28)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        if (this.settings.removeUser(item.id)) {
          persistPrompts(this.settings)
          this.toast('已删除')
        }
      })
    }
    .width("100%")
    .padding({ left: 12, right: 6, top: 10, bottom: 10 })
    .borderRadius(14)
    .backgroundColor($r("app.color.card_sub_bg"))
  }

  // ---------------- 编辑视图 ----------------

  @Builder
  buildEditor() {
    Column() {
      Row({ space: 8 }) {
        Button({ stateEffect: false }) {
          Text('‹ 返回')
            .fontSize(14)
            .fontColor($r("app.color.text_secondary"))
        }
        .height(32)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.editing = false
        })

        Text(this.editorTitle())
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r("app.color.primary_font_color"))

        Button('保存')
          .height(32)
          .fontSize(13)
          .fontColor($r("app.color.start_window_background"))
          .backgroundColor($r("app.color.primary_font_color"))
          .borderRadius(16)
          .padding({ left: 14, right: 14 })
          .onClick(() => this.saveDraft())
      }
      .width("100%")
      .height(44)

      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 6 }) {
            Text('名称')
              .width("100%")
              .fontSize(12)
              .fontColor($r("app.color.text_secondary"))
            TextInput({
              text: this.draftName,
              placeholder: this.editingType === 0 ? '例如 代码助手' : '例如 自我介绍'
            })
              .width("100%")
              .height(42)
              .fontSize(14)
              .fontColor($r("app.color.primary_font_color"))
              .placeholderColor($r("app.color.input_placeholder"))
              .backgroundColor($r("app.color.card_sub_bg"))
              .borderRadius(10)
              .padding({ left: 12, right: 12 })
              .onChange((value: string) => {
                this.draftName = value
              })
            Text('留空时会自动用内容开头作为名称')
              .width("100%")
              .fontSize(11)
              .fontColor($r("app.color.text_secondary"))
          }
          .width("100%")

          Column({ space: 6 }) {
            Text('内容')
              .width("100%")
              .fontSize(12)
              .fontColor($r("app.color.text_secondary"))
            TextArea({
              text: this.draftContent,
              placeholder: this.editingType === 0 ?
                '例如：你是一名资深软件工程师，回答技术问题时…' :
                '例如：帮我解释一下这段代码'
            })
              .width("100%")
              .height(150)
              .fontSize(14)
              .fontColor($r("app.color.primary_font_color"))
              .placeholderColor($r("app.color.input_placeholder"))
              .backgroundColor($r("app.color.card_sub_bg"))
              .borderRadius(10)
              .padding(12)
              .maxLength(4000)
              .onChange((value: string) => {
                this.draftContent = value
              })
            Text(this.editingType === 0 ?
              '系统提示词会作为每次请求的 system message 发送' :
              '点击空态中的快捷提示词时，会直接发送这段内容')
              .width("100%")
              .fontSize(11)
              .fontColor($r("app.color.text_secondary"))
          }
          .width("100%")

          if (this.editingId.length > 0) {
            Button(this.editingType === 0 ? '删除这套系统提示词' : '删除这条常用提示词')
              .width("100%")
              .height(38)
              .fontSize(13)
              .fontColor($r("app.color.error_text"))
              .backgroundColor(Color.Transparent)
              .margin({ top: 4 })
              .onClick(() => this.deleteCurrent())
          }
        }
        .width("100%")
      }
      .width("100%")
      .constraintSize({ maxHeight: 380 })
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width("100%")
  }

  private editorTitle(): string {
    if (this.editingType === 0) {
      return this.editingId.length === 0 ? '新增系统提示词' : '编辑系统提示词'
    }
    return this.editingId.length === 0 ? '新增常用提示词' : '编辑常用提示词'
  }
}
