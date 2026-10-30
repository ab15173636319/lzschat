import { AiSettings, useAiSettings } from "../model/AiSettings"
import { ModelDialogState, useModelDialog } from "../store/useModelDialog"
import { Slider, useSlider } from "../store/useSlider"

/**
 * 顶部栏：左菜单、标题、右侧当前模型（点击打开模型配置弹窗）
 */
@ComponentV2
export default struct Header {
  Menu: Resource = $rawfile("assets/slider.svg")
  slider: Slider = useSlider()
  settings: AiSettings = useAiSettings()
  dialog: ModelDialogState = useModelDialog()

  get modelLabel(): string {
    const active = this.settings.active
    if (active === null) {
      return '配置模型'
    }
    const model = active.model.trim()
    return model.length > 0 ? model : '配置模型'
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Text('LZS Chat')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r("app.color.primary_font_color"))

      Row() {
        Button() {
          Image(this.Menu)
            .width(20)
            .fillColor($r("app.color.primary_font_color"))
        }
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .onClick(() => this.slider.triggerOpen())

        Blank()

        Button({ stateEffect: true }) {
          Row({ space: 4 }) {
            Text(this.modelLabel)
              .fontSize(12)
              .fontColor($r("app.color.primary_font_color"))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: 92 })
            Text('▾')
              .fontSize(9)
              .fontColor($r("app.color.text_secondary"))
          }
        }
        .height(28)
        .padding({ left: 10, right: 10 })
        .borderRadius(14)
        .backgroundColor($r("app.color.input_area_bg"))
        .onClick(() => this.dialog.open())
      }
      .width("100%")
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width("100%")
    .height(44)
  }
}
