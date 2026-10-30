import ConversationMenuDialog from '../components/ConversationMenuDialog'
import EditMessageDialog from '../components/EditMessageDialog'
import MessageMenuDialog from '../components/MessageMenuDialog'
import ModelConfigDialog from '../components/ModelConfigDialog'
import PromptConfigDialog from '../components/PromptConfigDialog'
import Main from '../layout/Main'
import SliderBar from '../layout/Slider'
import { ConversationActionStore, useConversationActions } from '../store/useConversationActions'
import { ModelDialogState, useModelDialog } from '../store/useModelDialog'
import { PromptDialogState, usePromptDialog } from '../store/usePromptDialog'
import { Slider, useSlider } from '../store/useSlider'
import { SafeArea, useSafeArea } from '../store/useSafeArea'

@Entry
@ComponentV2
struct Index {
  @Param Slider: Resource = $rawfile("assets/slider.svg")
  @Local isOpen: boolean = false
  @Local modelDialog: ModelDialogState = useModelDialog()
  @Local promptDialog: PromptDialogState = usePromptDialog()
  @Local actions: ConversationActionStore = useConversationActions()
  slider: Slider = useSlider()
  safeArea: SafeArea = useSafeArea()

  onPageShow(): void {
    console.log("000", this.safeArea.top)
  }

  onBackPress(): boolean {
    if (this.actions.messageMenuVisible) {
      this.actions.closeMessageMenu()
      return true
    }
    if (this.actions.editVisible) {
      this.actions.closeEdit()
      return true
    }
    if (this.actions.menuVisible) {
      this.actions.closeMenu()
      return true
    }
    if (this.actions.selecting) {
      this.actions.cancelSelection()
      return true
    }
    if (this.promptDialog.visible) {
      this.promptDialog.close()
      return true
    }
    if (this.modelDialog.visible) {
      this.modelDialog.close()
      return true
    }
    if (this.slider.isOpen) {
      this.slider.close()
      return true
    }
    return false
  }

  build() {
    Stack({ alignContent: Alignment.Start }) {
      Main()
        .width("100%")
        .height("100%")
        .translate({ x: this.slider.contentX })
        .animation({ duration: 300, curve: Curve.EaseInOut })
        .onClick(() => {
          // 点主区域收起抽屉时，同时退出多选模式
          this.actions.cancelSelection()
          this.slider.open()
        })

      SliderBar()
        .width("90%")
        .height("100%")
        .translate({ x: this.slider.drawerX })
        .animation({ duration: 300, curve: Curve.EaseInOut })

      if (this.modelDialog.visible) {
        ModelConfigDialog()
      }

      if (this.promptDialog.visible) {
        PromptConfigDialog()
      }

      if (this.actions.menuVisible) {
        ConversationMenuDialog()
      }

      if (this.actions.editVisible) {
        EditMessageDialog()
      }

      if (this.actions.messageMenuVisible) {
        MessageMenuDialog()
      }
    }
    .width("100%")
    .height("100%")
    .clip(true)
    .backgroundColor($r("app.color.start_window_background"))
  }
}