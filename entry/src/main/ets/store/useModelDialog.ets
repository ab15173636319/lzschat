import { AppStorageV2 } from '@kit.ArkUI'

/**
 * 模型配置弹窗的显示状态
 */
@ObservedV2
export class ModelDialogState {
  @Trace visible: boolean = false

  open(): void {
    this.visible = true
  }

  close(): void {
    this.visible = false
  }
}

export function useModelDialog(): ModelDialogState {
  return AppStorageV2.connect(ModelDialogState, 'lzs_model_dialog', () => new ModelDialogState())!
}
