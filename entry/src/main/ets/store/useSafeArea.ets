import { AppStorageV2 } from "@kit.ArkUI"

@ObservedV2
export class SafeArea {
  // 顶部状态栏高度（vp）
  @Trace top: number = 0
  // 底部导航条高度（vp）
  @Trace bottom: number = 0
}

export function useSafeArea(): SafeArea {
  return AppStorageV2.connect(SafeArea, 'safeArea', () => new SafeArea())!
}
