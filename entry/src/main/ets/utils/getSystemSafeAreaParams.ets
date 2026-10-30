import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { useSafeArea } from '../store/useSafeArea';

interface AreaHeight {
  topHeightVp: number,
  bottomHeightVp: number
}

/**
 * 回去安全区域高度
 */
export async function getSafeAreaHeight(context: common.UIAbilityContext) {
  try {
    const mainWindow = await window.getLastWindow(context);

    // 获取系统避让区域（包含状态栏和导航条）
    const avoidAreaSystem = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    const topHeightPx = avoidAreaSystem.topRect.height; // 顶部状态栏高度（px）
    const bottomHeightPx = avoidAreaSystem.bottomRect.height; // 底部导航条高度（px）

    // 转换为 vp
    const uiContext = mainWindow.getUIContext();
    const topHeightVp = uiContext.px2vp(topHeightPx);
    const bottomHeightVp = uiContext.px2vp(bottomHeightPx);

    console.info(`状态栏高度: ${topHeightVp}vp, 导航条高度: ${bottomHeightVp}vp`);
    const safeArea = useSafeArea();
    safeArea.top = topHeightVp;
    safeArea.bottom = bottomHeightVp;
  } catch (err) {
    console.error('获取安全区域失败: ' + JSON.stringify(err));
    const safeArea = useSafeArea();
    safeArea.top = 0;
    safeArea.bottom = 0;
  }
}