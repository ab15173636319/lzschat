import { http } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { ModelProfile } from '../model/ModelProfile'

/** 单个币种的余额 */
interface BalanceInfo {
  currency?: string
  total_balance?: string
  granted_balance?: string
  topped_up_balance?: string
}

interface BalancePayload {
  is_available?: boolean
  balance_infos?: BalanceInfo[]
}

interface ApiErrorBody {
  message?: string
}

interface ApiErrorWrapper {
  error?: ApiErrorBody
}

/** 余额查询结果 */
export interface BalanceResult {
  /** 简短展示，例如 "¥110.00 / $5.00" */
  summary: string
  /** 明细，例如 "赠送 ¥10.00 · 充值 ¥100.00" */
  detail: string
}

function currencySymbol(currency: string): string {
  if (currency === 'CNY') {
    return '¥'
  }
  if (currency === 'USD') {
    return '$'
  }
  return currency.length > 0 ? `${currency} ` : ''
}

/**
 * DeepSeek 余额查询。
 *
 * 接口：GET https://api.deepseek.com/user/balance
 * 鉴权：Authorization: Bearer <API Key>
 * 返回：{ is_available, balance_infos: [{ currency, total_balance, granted_balance, topped_up_balance }] }
 *
 * 余额接口挂在域名根路径（不在 /v1 下），因此这里从 Base URL 取 scheme + host
 * 再拼 /user/balance；OpenAI 等其他兼容服务没有该接口，会返回 404。
 */
export class BalanceService {
  /** 从 Base URL 推导余额接口地址 */
  balanceUrl(profile: ModelProfile): string {
    let url = profile.baseUrl.trim()
    if (url.length === 0) {
      return ''
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = `https://${url}`
    }
    let origin = url
    const schemeIndex = url.indexOf('://')
    if (schemeIndex >= 0) {
      const pathIndex = url.indexOf('/', schemeIndex + 3)
      if (pathIndex > 0) {
        origin = url.substring(0, pathIndex)
      }
    }
    while (origin.endsWith('/')) {
      origin = origin.substring(0, origin.length - 1)
    }
    return `${origin}/user/balance`
  }

  /**
   * 查询余额，成功返回展示文案，失败抛 Error（message 可直接展示）
   */
  async query(profile: ModelProfile): Promise<BalanceResult> {
    const apiKey = profile.apiKey.trim()
    if (apiKey.length === 0) {
      throw new Error('请先填写 API Key')
    }
    const url = this.balanceUrl(profile)
    if (url.length === 0) {
      throw new Error('接口地址为空，无法查询余额')
    }

    const request = http.createHttp()
    let response: http.HttpResponse
    try {
      response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: this.buildHeader(apiKey),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 15000,
        usingCache: false
      })
    } catch (e) {
      request.destroy()
      throw new Error(this.describeNetworkError(e))
    }
    request.destroy()

    const statusCode = response.responseCode
    const body = response.result as string
    if (statusCode !== 200) {
      throw new Error(this.describeHttpError(body, statusCode))
    }
    const payload = this.parsePayload(body)
    return this.format(payload)
  }

  private buildHeader(apiKey: string): Object {
    const headers: Record<string, string> = {
      'Authorization': `Bearer ${apiKey}`,
      'Accept': 'application/json'
    }
    return headers
  }

  private parsePayload(body: string): BalancePayload {
    try {
      return JSON.parse(body) as BalancePayload
    } catch (e) {
      throw new Error('余额接口返回格式异常')
    }
  }

  private format(payload: BalancePayload): BalanceResult {
    const infos = payload.balance_infos
    if (infos === undefined || infos.length === 0) {
      const summary = payload.is_available === false ? '账户不可用' : '暂无余额信息'
      const result: BalanceResult = { summary: summary, detail: '' }
      return result
    }
    const summaryParts: string[] = []
    const detailParts: string[] = []
    for (const info of infos) {
      const currency = info.currency !== undefined ? info.currency : ''
      const total = info.total_balance !== undefined ? info.total_balance : '0'
      summaryParts.push(`${currencySymbol(currency)}${total}`)
      const granted = info.granted_balance !== undefined ? info.granted_balance : '0'
      const toppedUp = info.topped_up_balance !== undefined ? info.topped_up_balance : '0'
      detailParts.push(`赠送 ${currencySymbol(currency)}${granted} / 充值 ${currencySymbol(currency)}${toppedUp}`)
    }
    let summary = summaryParts.join(' / ')
    if (payload.is_available === false) {
      summary = `${summary}（不可用）`
    }
    const result: BalanceResult = {
      summary: summary,
      detail: detailParts.join('；')
    }
    return result
  }

  private describeHttpError(body: string, statusCode: number): string {
    if (statusCode === 401 || statusCode === 403) {
      return '鉴权失败，请检查 API Key 是否正确'
    }
    if (statusCode === 404) {
      return '当前服务不支持余额查询（DeepSeek 提供 /user/balance）'
    }
    if (statusCode === 429) {
      return '请求过于频繁，请稍后重试'
    }
    if (statusCode >= 500) {
      return '余额服务暂时不可用，请稍后重试'
    }
    let detail = ''
    const trimmed = body !== undefined ? body.trim() : ''
    if (trimmed.length > 0 && trimmed.startsWith('{')) {
      try {
        const parsed = JSON.parse(trimmed) as ApiErrorWrapper
        if (parsed.error !== undefined && parsed.error.message !== undefined) {
          detail = parsed.error.message
        }
      } catch (e) {
        detail = ''
      }
    }
    return detail.length > 0 ? `查询失败（HTTP ${statusCode}）：${detail}` : `查询失败（HTTP ${statusCode}）`
  }

  private describeNetworkError(error: Object): string {
    const e = error as BusinessError
    const code: number = e.code
    switch (code) {
      case 2300006:
        return '无法解析服务器域名，请检查网络'
      case 2300007:
        return '无法连接服务器，请检查网络'
      case 2300028:
        return '请求超时，请稍后重试'
      case 2300997:
        return '系统禁止明文 HTTP 请求，请改用 HTTPS'
      default:
        return '网络请求失败，请检查网络后重试'
    }
  }
}
