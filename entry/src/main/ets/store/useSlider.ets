import { AppStorageV2 } from "@kit.ArkUI"

@ObservedV2
export class Slider {
  @Trace isOpen: boolean = false
  // 抽屉：相对自身宽度平移（自身 = 80% 屏宽）→ -100% 等于移出 80% 屏宽
  @Trace drawerX: string = "-100%"
  // 主体：相对自身宽度平移（自身 = 100% 屏宽）→ 80% 等于右移 80% 屏宽
  @Trace contentX: string = "0%"

  triggerOpen() {
    this.isOpen = !this.isOpen
    this.drawerX = this.isOpen ? "0%" : "-100%"
    this.contentX = this.isOpen ? "90%" : "0%"
  }

  open() {
    if (!this.isOpen) {
      return
    }
    this.close()
  }

  close() {
    this.isOpen = false
    this.drawerX = "-100%"
    this.contentX = "0%"
  }
}


export function useSlider(): Slider {
  return AppStorageV2.connect(Slider, 'slider', () => new Slider())!
}