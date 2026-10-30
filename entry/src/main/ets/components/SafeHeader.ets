import { SafeArea, useSafeArea } from "../store/useSafeArea"
/**
 * 顶部安全区域
 */
@ComponentV2
export default struct SafeHeader {
  safeArea: SafeArea = useSafeArea()

  build() {

    Column()
      .width("100%")
      .height(this.safeArea.top)

  }
}