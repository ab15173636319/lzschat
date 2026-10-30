# LZS Chat

基于 HarmonyOS ArkTS 的聊天应用：主页 + 抽屉式侧边栏 + 接入任意 OpenAI 兼容服务的流式对话，支持多套模型、多会话、自定义提示词，全部数据本地持久化。

- 开发环境：DevEco Studio + HarmonyOS SDK **6.1.1(24)**（`build-profile.json5` 中 `compatibleSdkVersion = "6.1.1(24)"`，`targetSdkVersion = "26.0.0"`），仅手机
- 网络权限：`ohos.permission.INTERNET`（`entry/src/main/module.json5` 已声明）
- 技术栈：`@ComponentV2` / `@ObservedV2` / `@Trace` 状态管理，`@kit.NetworkKit` 流式请求，`PersistenceV2` 本地存储

## 功能

### 对话

- **流式输出**：SSE 增量解析，逐字渲染；等待首字时显示「正在思考…」，生成中在文本末尾显示 `▍` 光标
- **气泡样式**：不使用气泡底色，改用「角色名 + 竖线」排版——用户消息靠右、金色「你」+ 右侧竖线；AI 消息靠左、角色名 + 左侧细线
- **括号旁白**：AI 回复中 `()` / `（）` 内的说明文字自动拆成独立小字斜体行，正文与旁白分段渲染
- **角色名**：AI 侧显示当前系统提示词的名称（未选或为默认时显示 `AI`）
- **停止 / 重试**：生成中发送按钮变为停止方块，停止保留已生成内容并标注「已停止生成」；失败消息内嵌错误原因与「重试」按钮
- **键盘与滚动**：内容变化自动滚到底部，点击消息区收起键盘

### 会话

- **多会话**：侧边栏新建 / 切换 / 删除，按最近更新时间倒序；标题取首条用户消息前 18 字，侧边栏显示最后一条消息预览与时间（当天 `HH:mm`，更早 `MM-DD`）
- **去重空会话**：当前会话本来就是空的时候，「新建对话」直接复用，不堆积空壳
- **长按会话菜单**：复制（整段对话格式化为 `你：…` / `AI：…` 文本写入剪贴板）/ 修改 / 删除
- **多选删除**：从菜单删除进入多选模式，每行左侧出现复选框，底部切换为「取消 / 删除」操作栏；全部删完自动补一个空会话
- **修改**：只能改最后一条用户消息，提交后丢弃其后的回复并立即重新生成

### 消息

- **点击用户消息**：弹出「复制 / 修改 / 删除」菜单，2 秒无操作自动关闭
- **删除**：移除该用户消息及其之后的所有内容
- **输入限制**：单条消息最多 12000 字（`InputArea` 的 `maxLength`）

### 模型

- 可保存多套模型配置（名称 / 接口地址 / API Key / 模型名 / 上下文消息数 / 最大回复 tokens），Header 右侧按钮弹窗中切换
- 至少保留一套；未配置完成的模型（缺地址或 Key）发送时自动拉起配置弹窗并提示
- **余额查询**：配置弹窗内展示 DeepSeek 账户余额（`GET https://api.deepseek.com/user/balance`），侧边栏同步显示摘要

### 提示词

- **系统提示词**：可保存多套，点选一套作用于所有对话，作为每次请求的首条 `system` 消息；至少保留一套
- **常用提示词**：保存在本地，作为新对话空态的快捷发送按钮，点击即作为用户消息发出
- 首次启动预置 3 套系统提示词（通用助手 / 代码助手 / 翻译润色）与 3 条常用提示词

### 其他

- **本地持久化**：会话、消息、模型配置、提示词全部保存在本机，重启恢复；上次生成到一半被强杀的消息会自动标记为中断
- **明暗主题**：跟随系统（`COLOR_MODE_NOT_SET`）
- **安全区与键盘**：`EntryAbility` 统一设置全屏、`KeyboardAvoidMode.RESIZE` 并读取安全区高度
- **返回键**：按优先级依次关闭消息菜单 → 编辑弹窗 → 会话菜单 → 多选模式 → 提示词弹窗 → 模型弹窗 → 侧边栏

## 快速开始

1. 用 DevEco Studio 打开工程（SDK 使用 **6.1.1(24)**），等待 `oh_modules` 同步完成。
2. 运行到真机 / 模拟器。
3. 点击 Header 右侧的模型按钮 →「+ 新增模型」，填写：
   - **名称**：任意，如「DeepSeek 官方」
   - **接口地址**：默认 `https://api.deepseek.com/v1`，任何 OpenAI 兼容服务均可
   - **API Key**：对应平台的 Key
   - **模型**：默认 `deepseek-chat`
   - **上下文消息数 / 最大回复 tokens**：默认 40 / 4096，按模型能力调整
4. 保存后自动选中，输入消息即可对话。
5. 左上角菜单打开侧边栏：全部对话（新建 / 切换 / 删除）、模型（切换）、提示词（系统 / 常用）。

> 旧版本（单模型配置 `lzs_ai_config`）保存的数据会在首次启动时自动迁移成一套模型配置。

### 接口地址容错

`ModelProfile.resolveChatUrl()` 会自动补全：

| 填写内容 | 实际请求地址 |
| --- | --- |
| `api.deepseek.com` | `https://api.deepseek.com/chat/completions` |
| `https://api.deepseek.com/v1` | `https://api.deepseek.com/v1/chat/completions` |
| `https://api.deepseek.com/v1/chat/completions` | 原样使用 |

末尾多余的 `/` 会被去掉；未写协议时默认补 `https://`。

## 目录结构

```text
entry/src/main/ets
├── model
│   ├── ChatMessage.ets        # 消息模型（角色、内容、状态、错误、时间）
│   ├── Conversation.ets       # 会话：标题、预览、时间标签、消息列表
│   ├── ConversationStore.ets  # 多会话状态 + 序列化 + 持久化
│   ├── PromptItem.ets         # 单条提示词
│   ├── PromptSettings.ets     # 提示词库（系统 + 常用）+ 持久化
│   ├── AiSettings.ets         # 多模型配置集合 + 旧版迁移 + 持久化
│   └── ModelProfile.ets       # 单个模型配置（URL 补全、参数裁剪）
├── service
│   ├── ChatService.ets        # OpenAI 兼容流式请求 + SSE 解析 + 错误文案
│   └── BalanceService.ets     # DeepSeek 余额查询
├── utils
│   ├── ChatTextParser.ets     # 括号旁白解析，拆分正文 / 旁白片段
│   ├── Clipboard.ets          # 会话文本格式化 + 系统剪贴板
│   └── getSystemSafeAreaParams.ets # 安全区高度
├── store
│   ├── useChat.ets            # 聊天核心：发送 / 停止 / 重试 / 会话切换 / 编辑 / 删除
│   ├── useConversationActions.ets # 长按菜单 / 多选 / 消息菜单 / 编辑弹窗状态
│   ├── useBalance.ets         # 余额查询状态
│   ├── useModelDialog.ets     # 模型弹窗显隐
│   ├── usePromptDialog.ets    # 提示词弹窗显隐
│   ├── useSlider.ets          # 抽屉位移状态
│   └── useSafeArea.ets        # 安全区
├── components
│   ├── ModelConfigDialog.ets  # 模型弹窗（列表 + 编辑 + 余额）
│   ├── PromptConfigDialog.ets # 提示词弹窗（系统 / 常用两个 Tab + 编辑）
│   ├── ConversationMenuDialog.ets # 长按会话菜单（复制 / 修改 / 删除）
│   ├── MessageMenuDialog.ets  # 点击用户消息的菜单（2 秒自动关闭）
│   ├── EditMessageDialog.ets  # 修改最后一条用户消息
│   ├── MessageBoard.ets       # 消息列表 / 空态快捷提示词 / 自动滚动
│   ├── MessageBubble.ets      # 消息气泡（正文 / 旁白 / 状态 / 重试）
│   ├── InputArea.ets          # 输入框与发送 / 停止按钮
│   ├── Header.ets             # 顶栏（右侧当前模型）
│   ├── SafeHeader.ets
│   └── SafeBottom.ets
├── layout
│   ├── Main.ets               # 主页布局（Header + 消息区 + 输入区 + 键盘监听）
│   └── Slider.ets             # 侧边栏（对话列表 / 模型 / 提示词 / 多选操作栏）
├── entryability/EntryAbility.ets  # 全屏、安全区、键盘避让、主题
└── pages/Index.ets            # 入口页面（抽屉位移 + 弹窗挂载 + 返回键处理）
```

## 数据流

```text
InputArea / 空态提示词按钮
        │ sendText()
        ▼
ChatStore ──► Conversation.messages（追加 user 消息）
        │
        ├─► persistConversations()  ← 立即落盘
        │
        └─► requestCompletion()
              ├─ buildHistory()：system 提示词 + 最近 N 条有效消息（字符预算裁剪）
              ├─ ChatService.stream()：requestInStream + SSE 增量回调
              │      └─ onDelta → aiMessage.content += delta（@Trace 驱动气泡刷新）
              └─ 结束 / 停止 / 失败 → 更新消息状态 → persistConversations()
```

状态全部挂在 `AppStorageV2` 单例上，组件通过 `useChat()` / `useAiSettings()` / `usePromptSettings()` / `useConversationActions()` 等 hook 取同一份实例；写入通过 `@Trace` 字段整体替换（`this.messages = next`）触发刷新。

## 持久化

三个独立的 `PersistenceV2` key，每个只存一个 JSON 字符串快照：

| key | 结构 |
| --- | --- |
| `lzs_conversations` | `{ activeId, conversations: [{ id, title, createdAt, updatedAt, messages: [{ id, role, content, status, error, createdAt }] }] }` |
| `lzs_ai_settings` | `{ activeId, profiles: [{ id, name, baseUrl, apiKey, model, temperature, contextMessages, maxTokens }] }` |
| `lzs_prompts` | `{ activeSystemId, systemPrompts: [{ id, name, content }], userPrompts: [...] }` |

- 写入时机：发送消息、回复结束/停止、切换/新建/删除会话、修改消息、修改模型或提示词——每次变更后调用 `PersistenceV2.save(key)` 立即落盘
- 流式生成过程中**不**逐字落盘，强杀应用可能丢失当前未完成的一段回复；下次启动时该消息按内容判定为「完成」或「上次回复被中断」
- 采用 JSON 快照而非直接持久化嵌套对象：`@ObservedV2` 实例序列化会产生 `__ob_` 前缀，反序列化后丢失类型与 `@Trace`
- 数据损坏或结构不符时回退到默认状态（一个新会话 / 默认模型配置 / 默认提示词），不会崩溃

## 容量与参数限制

| 项目 | 限制 | 位置 |
| --- | --- | --- |
| 会话数 | 30（超出时丢弃最旧的，当前会话一定保留） | `ConversationStore.MAX_CONVERSATIONS` |
| 单会话消息数 | 持久化最近 500 条 | `MAX_MESSAGES_PER_CONVERSATION` |
| 单次请求消息数 | 模型配置的上下文消息数，2–200（全局上限 200） | `useChat.MAX_CONTEXT_MESSAGES` |
| 单次请求字符预算 | 约 32000 字符，从最新往前取，最新一条必带 | `MAX_CONTEXT_CHARS` |
| 单条消息长度 | 12000 字（输入框 `maxLength`） | `InputArea` |
| 最大回复 tokens | 0–32768，0 表示交给服务端默认值 | `ModelProfile.resolveMaxTokens()` |
| 单次响应上限 | 8 MB，超出立即中断并提示数据异常 | `ChatService.MAX_BODY_LENGTH` |
| 超时 | 连接 30s；`readTimeout = 0`（SSE 两次数据间可能长时间静默，避免 60s 误杀） | `ChatService` |

## 实现要点

- **SSE 解析**：`requestInStream` + `on('dataReceive')`，`TextDecoder.decodeToString(..., { stream: true })` 处理跨块多字节 UTF-8；按 `\n` 缓冲分行，只处理 `data:` 前缀行，兼容 `data: [DONE]`、流内 `error` 对象、以及非 JSON 注释行；网关忽略 `stream:true` 直接返回完整 JSON 时，从 `choices[0].message.content` 兜底取全文
- **并发安全**：`ChatService` 维护请求代际 token（`cancel()` 自增），`ChatStore` 维护请求序号（`requestSeq`），回调里的旧请求一律丢弃，停止或切会话后立刻发新消息不会串数据
- **流式渲染性能**：消息列表用 `message.id` 作稳定 key，流式追加内容时不重建整个列表；仅靠 `@Trace` 字段与 `tick` 版本号驱动滚动
- **历史裁剪**：`buildHistory()` 从最新往前收集，跳过空内容、错误状态与正在生成的占位消息，跳过当前 AI 占位消息自身；超过字符预算即停止，保证最新一轮一定带上
- **括号旁白**：`parseChatText()` 逐个字符扫描 `(` / `（` 到最近的 `)` / `）`；未闭合时剩余文本暂按正文显示（流式中常见），闭合后自动切换成旁白
- **长按识别**：会话行用「手动 450ms 计时器 + `LongPressGesture`」双保险触发菜单，手指移动超过 15vp 视为滚动列表并取消，避免误触
- **交互保护**：会话菜单打开后 400ms 内忽略遮罩点击；长按后 800ms 内抑制长按松手触发的点击；消息菜单用自增序号 + 2s 定时器，重复打开不会误关；点击非最后一条用户消息的「修改」时提示「只能修改最后一条用户消息」
- **错误可读化**：`ChatService.describeNetworkError()` 把 `2300006/2300007/2300028/2300997` 等错误码翻译成中文提示；`describeApiError()` 覆盖 401/403/404/429/5xx 并附带服务端 `error.message`

## 构建

```bash
# DevEco Studio 直接 Build，或命令行：
hvigorw assembleHap --mode module -p product=default -p buildMode=debug
```

产物：`entry/build/default/outputs/default/entry-default-signed.hap`

## 已知限制

- API Key 以明文保存在应用本地持久化数据中，仅适合个人调试；生产环境建议使用 Asset Store 或自建后端中转
- 若使用 `http://` 本地服务（如 Ollama），系统可能拒绝明文请求（错误码 `2300997`），需改用 HTTPS 或配置网络安全策略
- 余额查询依赖 DeepSeek 的 `/user/balance`（挂在域名根路径，不在 `/v1` 下），其他兼容服务返回 404 时提示「当前服务不支持余额查询」
- 界面未暴露 `temperature` 配置项，统一使用默认值 `0.7`
