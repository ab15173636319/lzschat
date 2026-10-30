import Header from "../components/Header"
import InputArea from "../components/InputArea"
import MessageBoard from "../components/MessageBoard"
import SafeBottom from "../components/SafeBottom"
import SafeHeader from "../components/SafeHeader"
import { window } from "@kit.ArkUI"

@ComponentV2
export default struct Main {
  @Local keyboardIsShow: boolean = false

  aboutToAppear(): void {
    window.getLastWindow(this.getUIContext().getHostContext()).then((currentWindow) => {
      currentWindow.on('keyboardHeightChange', (data: number) => {
        if (data > 0) {
          this.keyboardIsShow = true
          console.info('键盘已弹出，高度：' + data);
        } else {
          this.keyboardIsShow = false
          console.info('键盘已收起');
        }
      });
    });
  }

  hideKeyboard() {
    if (!this.keyboardIsShow) {
      return
    }
    this.keyboardIsShow = false
    this.getUIContext().getFocusController().clearFocus()
  }

  build() {
    Column() {
      Column() {
        SafeHeader()
        Header()
        MessageBoard()
          .layoutWeight(1)
      }
      .layoutWeight(1)
      .onClick(() => this.hideKeyboard())

      InputArea()
      SafeBottom()
    }
    .width("100%")
    .height("100%")
    .padding(10)
  }
}