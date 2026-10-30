import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'

/**
 * 发送给 AI 服务的一条历史消息
 */
export interface ChatApiMessage {
  role: string
  content: string
}

/**
 * 一次流式对话的参数
 */
export interface ChatStreamOptions {
  url: string
  apiKey: string
  model: string
  temperature: number
  /** 最大回复 tokens，<=0 时不传，使用服务端默认值 */
  maxTokens: number
  messages: ChatApiMessage[]
  /** 每收到一小段文本就回调一次 */
  onDelta: (delta: string) => void
}

/** SSE 数据块结构（OpenAI 兼容协议） */
interface ChunkDelta {
  role?: string
  content?: string
  reasoning_content?: string
}

interface ChunkChoice {
  index?: number
  delta?: ChunkDelta
  finish_reason?: string
}

interface ApiErrorBody {
  message?: string
  type?: string
  code?: string
}

interface ChatChunk {
  choices?: ChunkChoice[]
  error?: ApiErrorBody
}

/** 兼容不返回 SSE、直接返回完整 JSON 的网关 */
interface CompletionMessage {
  content?: string
}

interface CompletionChoice {
  message?: CompletionMessage
}

interface CompletionResponse {
  choices?: CompletionChoice[]
  error?: ApiErrorBody
}

interface ApiErrorWrapper {
  error?: ApiErrorBody
  message?: string
}

/** 请求体 */
interface ChatCompletionBody {
  model: string
  messages: ChatApiMessage[]
  stream: boolean
  temperature: number
  max_tokens?: number
}

/** 响应体最大长度保护，避免异常服务端把内存撑爆 */
const MAX_BODY_LENGTH = 8 * 1024 * 1024

/**
 * OpenAI 兼容协议的流式聊天服务。
 *
 * 通过 @kit.NetworkKit 的 requestInStream 接收 SSE 增量数据，
 * 把每个 data 事件里的 delta.content 回调给上层，实现打字机效果。
 */
export class ChatService {
  private request: http.HttpRequest | null = null
  private finishCurrent: (() => void) | null = null
  /**
   * 请求代际：每次 cancel/新建请求都会自增。
   * 异步回调里只有 token 仍等于当前代际时才允许改动状态，
   * 避免「停止后立刻再发」时旧请求污染新请求。
   */
  private generation: number = 0

  /** 是否正在请求中 */
  isRunning(): boolean {
    return this.request !== null
  }

  /**
   * 中止当前请求。会立即解除挂起并释放底层连接。
   */
  cancel(): void {
    this.generation += 1
    const finish = this.finishCurrent
    this.finishCurrent = null
    if (finish !== null) {
      finish()
    }
    this.disposeRequest()
  }

  private disposeRequest(): void {
    const request = this.request
    this.request = null
    if (request === null) {
      return
    }
    try {
      request.off('dataReceive')
      request.off('dataEnd')
    } catch (e) {
      // 忽略解绑异常
    }
    request.destroy()
  }

  /**
   * 发起一次流式对话，Promise 在流结束后 resolve。
   * 出错时 reject(Error)，被 cancel 时静默 resolve。
   */
  async stream(options: ChatStreamOptions): Promise<void> {
    this.cancel()
    const token = this.generation

    const url = options.url
    if (url.length === 0) {
      throw new Error('接口地址为空，请先在侧边栏配置 AI 服务')
    }
    if (options.apiKey.trim().length === 0) {
      throw new Error('请先在侧边栏填写 API Key')
    }

    const body: ChatCompletionBody = {
      model: options.model,
      messages: options.messages,
      stream: true,
      temperature: options.temperature
    }
    if (options.maxTokens > 0) {
      body.max_tokens = options.maxTokens
    }
    const request = http.createHttp()
    this.request = request

    const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true })
    let rawBody = ''
    let lineBuffer = ''
    let streamError = ''
    let receivedAnyDelta = false

    let resolveFinish: () => void = (): void => {}
    const finishedPromise = new Promise<void>((resolve) => {
      resolveFinish = (): void => resolve()
    })
    this.finishCurrent = (): void => {
      resolveFinish()
    }

    const handleLine = (line: string): void => {
      const trimmed = line.trim()
      if (trimmed.length === 0 || !trimmed.startsWith('data:')) {
        return
      }
      const payload = trimmed.substring(5).trim()
      if (payload.length === 0) {
        return
      }
      if (payload === '[DONE]') {
        // 部分网关在 [DONE] 之后不主动断开连接，这里主动结束等待
        resolveFinish()
        return
      }
      let chunk: ChatChunk
      try {
        chunk = JSON.parse(payload) as ChatChunk
      } catch (e) {
        // 非 JSON 的 data 行（部分网关会插入注释）直接忽略
        return
      }
      if (chunk.error !== undefined && chunk.error.message !== undefined) {
        streamError = chunk.error.message
        return
      }
      const choices = chunk.choices
      if (choices === undefined || choices.length === 0) {
        return
      }
      const delta = choices[0].delta
      if (delta !== undefined && delta.content !== undefined && delta.content.length > 0) {
        receivedAnyDelta = true
        options.onDelta(delta.content)
      }
    }

    const flushLines = (): void => {
      if (lineBuffer.length === 0) {
        return
      }
      const rest = lineBuffer
      lineBuffer = ''
      handleLine(rest)
    }

    request.on('dataReceive', (data: ArrayBuffer) => {
      if (token !== this.generation) {
        return
      }
      let text = ''
      try {
        text = decoder.decodeToString(new Uint8Array(data), { stream: true })
      } catch (e) {
        return
      }
      if (rawBody.length < MAX_BODY_LENGTH) {
        rawBody += text
      }
      lineBuffer += text
      if (lineBuffer.length > MAX_BODY_LENGTH) {
        lineBuffer = ''
        streamError = '服务端返回的数据异常，已停止接收'
        this.cancel()
        return
      }
      let newlineIndex = lineBuffer.indexOf('\n')
      while (newlineIndex >= 0) {
        const line = lineBuffer.substring(0, newlineIndex)
        lineBuffer = lineBuffer.substring(newlineIndex + 1)
        handleLine(line)
        newlineIndex = lineBuffer.indexOf('\n')
      }
    })

    request.on('dataEnd', () => {
      flushLines()
      resolveFinish()
    })

    const requestOptions: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: this.buildHeader(options.apiKey),
      extraData: JSON.stringify(body),
      connectTimeout: 30000,
      // 0 表示不限时：SSE 在两次数据之间可能长时间没有响应，默认 60s 会误杀
      readTimeout: 0,
      usingCache: false
    }

    let statusCode = 0
    try {
      statusCode = await request.requestInStream(url, requestOptions)
    } catch (e) {
      if (token !== this.generation) {
        return
      }
      resolveFinish()
      this.disposeRequest()
      this.finishCurrent = null
      throw new Error(describeNetworkError(e))
    }

    await finishedPromise
    if (token !== this.generation) {
      // 已被停止或被新请求取代，旧请求不再改动任何状态
      return
    }
    this.finishCurrent = null
    this.disposeRequest()

    if (statusCode < 200 || statusCode >= 300) {
      throw new Error(describeApiError(rawBody, statusCode))
    }
    if (streamError.length > 0) {
      throw new Error(streamError)
    }
    if (!receivedAnyDelta) {
      // 兼容忽略 stream=true、直接返回完整 JSON 的网关
      const fallback = extractNonStreamContent(rawBody)
      if (fallback.length > 0) {
        options.onDelta(fallback)
      }
    }
  }

  private buildHeader(apiKey: string): Object {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      'Authorization': `Bearer ${apiKey.trim()}`
    }
    return headers
  }
}

/** 把网络错误转换成用户能看懂的话 */
function describeNetworkError(error: Object): string {
  const e = error as BusinessError
  const code: number = e.code
  const detail: string = e.message !== undefined ? e.message : ''
  let reason = '网络请求失败'
  switch (code) {
    case 201:
      reason = '缺少网络权限'
      break
    case 2300003:
      reason = '接口地址格式不正确'
      break
    case 2300005:
    case 2300006:
      reason = '无法解析服务器域名，请检查网络或接口地址'
      break
    case 2300007:
      reason = '无法连接服务器，请检查网络或接口地址'
      break
    case 2300028:
      reason = '请求超时，请稍后重试'
      break
    case 2300997:
      reason = '系统禁止明文 HTTP 请求，请改用 HTTPS 地址'
      break
    case 2300056:
      reason = '接收数据失败，连接可能已断开'
      break
    default:
      reason = '网络请求失败'
      break
  }
  if (detail.length > 0) {
    return `${reason}（${code}）`
  }
  return reason
}

/** 把 HTTP 错误响应转换成用户能看懂的话 */
function describeApiError(rawBody: string, statusCode: number): string {
  let detail = ''
  const trimmed = rawBody.trim()
  if (trimmed.length > 0) {
    try {
      const parsed = JSON.parse(trimmed) as ApiErrorWrapper
      if (parsed.error !== undefined && parsed.error.message !== undefined) {
        detail = parsed.error.message
      } else if (parsed.message !== undefined) {
        detail = parsed.message
      }
    } catch (e) {
      detail = trimmed.substring(0, 300)
    }
  }
  let reason = ''
  switch (statusCode) {
    case 401:
    case 403:
      reason = '鉴权失败，请检查 API Key 是否正确'
      break
    case 404:
      reason = '接口地址不存在，请检查 Base URL'
      break
    case 429:
      reason = '请求过于频繁或额度不足，请稍后重试'
      break
    default:
      reason = statusCode >= 500 ? 'AI 服务暂时不可用，请稍后重试' : `请求失败（HTTP ${statusCode}）`
      break
  }
  if (detail.length > 0 && statusCode !== 401 && statusCode !== 403) {
    return `${reason}：${detail}`
  }
  return reason
}

/** 从非流式响应（完整 JSON）中取出回复正文 */
function extractNonStreamContent(rawBody: string): string {
  const trimmed = rawBody.trim()
  if (trimmed.length === 0) {
    return ''
  }
  try {
    const parsed = JSON.parse(trimmed) as CompletionResponse
    const choices = parsed.choices
    if (choices === undefined || choices.length === 0) {
      return ''
    }
    const message = choices[0].message
    if (message !== undefined && message.content !== undefined) {
      return message.content
    }
  } catch (e) {
    return ''
  }
  return ''
}
