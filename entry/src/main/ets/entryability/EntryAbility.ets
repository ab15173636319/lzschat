import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window, KeyboardAvoidMode } from '@kit.ArkUI';
import { getSafeAreaHeight } from '../utils/getSystemSafeAreaParams';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');


      try {
        const windowClass = windowStage.getMainWindowSync();

        // 设置全屏
        windowClass.setWindowLayoutFullScreen(true)
          .catch((e: BusinessError) => {
            hilog.error(DOMAIN, 'testTag', '设置全屏失败: %{public}s', JSON.stringify(e));
          })

        getSafeAreaHeight(this.context)

        const uiContext = windowClass.getUIContext();
        uiContext.setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
        // 验证是否真的生效：RESIZE 应返回 1
        hilog.info(DOMAIN, 'testTag', 'keyboardAvoidMode = %{public}s',
          JSON.stringify(uiContext.getKeyboardAvoidMode()));
      } catch (e) {
        hilog.error(DOMAIN, 'testTag', 'setKeyboardAvoidMode failed: %{public}s', JSON.stringify(e));
      }
    });

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to setColorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }


  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}