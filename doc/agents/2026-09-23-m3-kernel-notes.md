# M3 聊天内核交接

日期：2026-09-23
状态：完成（commit 见 git log，模拟器 401 错误路径实测通过）

## 完成内容
- OpenAI/Anthropic SSE 流式全量实现（映射细节见 protocol-mapping.md v1.0）
- 重试仅请求建立阶段（429/5xx/网络，退避 ≤2 次）；流式中断不再重试
- context crate：token 估算 + plan_context + 滚动摘要（bridge 编排，复用会话 Provider）
- bridge：chat_send（StreamSink）/ chat_cancel（abort tokio 任务）
- 测试：25 单测 + 4 集成测试（mock SSE 服务器，fixtures 在 crates/api/tests/fixtures/）

## 踩坑
- **SSE 样本必须空行结尾**：EOF 前最后一个事件没有 `\n\n` 时 eventsource-stream 不派发，测试挂了半小时才定位。
- **mock 服务器要读完请求体再响应**：只读 header 就关连接会 RST，客户端收不到响应。
- **frb 枚举需要 freezed**：ChatEventDto 触发 freezed 依赖（freezed_annotation + dev: freezed/build_runner 已加）。

## 待办（不阻塞，M5 打磨时处理）
- **错误展示噪音**：anyhow 错误经 frb 到 Dart 侧带 Rust backtrace（`<unknown>` 栈帧几十行）。方向：bridge 收敛为自定义错误类型（Display 只含 code+message），不走 anyhow Debug。
- `flutter run` VM Service 在 adb 桥接下不可用（M1 notes 已记），本次用 APK + uiautomator dump 验证，坐标全部从 dump 取，别从截图估算。
