# M4 聊天 UI 交接

日期：2026-09-23
状态：完成（模拟器全链路实测通过：mock SSE 流式对话 + 重新生成 + 持久化）

## 完成内容
- storage：Conversation/Message CRUD + 0002 迁移（conversation.profile_id）；消息排序/删除用 rowid 决胜（created_at 毫秒同值碰撞）
- bridge：会话/消息桥接；chat 改为 DB 驱动（chat_send/regenerate/edit_resend）；**取消改用 watch 信号 + select!**（弃 abort），取消时部分内容以 cancelled 正常落库
- Dart：会话列表页（置顶/重命名/删除/新建）、聊天页（模型切换 bottom sheet、流式渲染、停止按钮、长按菜单、编辑重发对话框）、BlockedMarkdown（决策三 spike 定稿）
- 测试：3 个 markdown widget 测试（隔离了 flutter_markdown pre builder 断言 bug）

## 踩坑（重要）
1. **flutter_markdown pre builder 断言**：自定义 `pre` builder → `_inlines.isEmpty` 崩溃；`selectable: true` 同病。代码块整块自渲染绕开（decisions.md 决策三已回写）。
2. **Provider 竞态**：`profilesProvider`/`conversationsProvider`/`chatProvider` 都必须 `await ref.watch(coreInitProvider.future)`，否则早于 initCore 调用报 "core not initialized"。新 Provider 照此办理。
3. **initCore/密钥注入必须幂等**：Android 退后台进程被缓存，重进时 isolate 重建但 native 静态区还在，OnceLock 二次 set 会失败。crypto.set_master_key 同 key 幂等，init_core 同理。
4. **模拟器联调 mock 链路**：`mock_sse.py`（仓库根，python3 直跑，127.0.0.1:8899）+ `adb reverse tcp:8899 tcp:8899`（设备 localhost → Windows → WSL localhostForwarding）。App 里 base_url 填 `http://localhost:8899/v1`。**Android 明文 HTTP 只在 debug manifest 允许**（usesCleartextTraffic，release 不含）。
5. **uiautomator dump 是自动化验证的正解**：所有坐标从 dump 的 bounds 取，不要从截图估算；文本输入用 `input text`（空格会截断，中文不行）；截图验证视觉。
6. anyhow 错误到 Dart 仍带 backtrace 噪音（M3 已记，M5 处理）。

## 已知留白（非 bug）
- 消息选择复制（selectable 文本）未做，用长按复制整段替代
- 消息分页未做（全量加载，千条内无压力）
- 图片消息在 M4b/M5（输入栏 + 号、vision 模型入口）
