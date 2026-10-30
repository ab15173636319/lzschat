import { AppStorageV2 } from '@kit.ArkUI'

/**
 * 提示词弹窗的显示状态
 */
@ObservedV2
export class PromptDialogState {
  @Trace visible: boolean = false

  open(): void {
    this.visible = true
  }

  close(): void {
    this.visible = false
  }
}

export function usePromptDialog(): PromptDialogState {
  return AppStorageV2.connect(PromptDialogState, 'lzs_prompt_dialog', () => new PromptDialogState())!
}
