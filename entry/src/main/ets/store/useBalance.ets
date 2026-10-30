import { AppStorageV2 } from '@kit.ArkUI'
import { ModelProfile } from '../model/ModelProfile'
import { BalanceService } from '../service/BalanceService'

/**
 * 余额查询状态（页面级缓存）
 * 只缓存最近一次查询结果，展示时通过 profileId 判断是否属于当前模型。
 */
@ObservedV2
export class BalanceStore {
  @Trace loading: boolean = false
  @Trace summary: string = ''
  @Trace detail: string = ''
  @Trace error: string = ''
  @Trace profileId: string = ''
  @Trace updatedAt: number = 0

  private service: BalanceService = new BalanceService()
  /** 请求序号，避免多次点击时旧结果覆盖新结果 */
  private seq: number = 0

  /** 缓存结果是否属于指定模型配置 */
  isFor(profileId: string): boolean {
    return this.profileId.length > 0 && this.profileId === profileId
  }

  clear(): void {
    this.seq += 1
    this.loading = false
    this.summary = ''
    this.detail = ''
    this.error = ''
    this.profileId = ''
    this.updatedAt = 0
  }

  async refresh(profile: ModelProfile): Promise<void> {
    const requestId = ++this.seq
    this.profileId = profile.id
    this.loading = true
    this.error = ''
    try {
      const result = await this.service.query(profile)
      if (requestId !== this.seq) {
        return
      }
      this.summary = result.summary
      this.detail = result.detail
      this.updatedAt = Date.now()
    } catch (e) {
      if (requestId !== this.seq) {
        return
      }
      const error = e as Error
      this.summary = ''
      this.detail = ''
      this.error = error.message !== undefined && error.message.length > 0 ? error.message : '查询失败，请稍后重试'
    } finally {
      if (requestId === this.seq) {
        this.loading = false
      }
    }
  }
}

/** 全局唯一的余额查询状态 */
export function useBalance(): BalanceStore {
  return AppStorageV2.connect(BalanceStore, 'lzs_balance', () => new BalanceStore())!
}
