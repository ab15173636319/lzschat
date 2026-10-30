import { SafeArea, useSafeArea } from "../store/useSafeArea"

/**
 * 底部安全区域
 */
@ComponentV2
export default struct SafeBottom {
  safeArea: SafeArea = useSafeArea()

  build() {
    Column() {
    }
    .width("100%")
    .height(20 + this.safeArea.bottom)

  }
}