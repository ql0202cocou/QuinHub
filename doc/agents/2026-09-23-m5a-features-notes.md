# M5a 功能批次交接（图片消息 / 导出分享 / 错误降噪）

日期：2026-09-23
状态：完成（模拟器实测：带图对话、导出 Markdown、分享长图均通过）

## 完成内容
- **图片消息**：ChatMessage 加 `images: Vec<ImageData>`（base64）；OpenAI 转 `image_url` parts、Anthropic 转 `image source base64`（图片在前文本在后）；DB content 为 JSON parts（`[{type:text},{type:image,mime,file}]`，纯文本保持纯文本兼容旧数据）；图片二进制落 `appDir/files/`（flutter_image_compress 压缩为 jpeg q85），历史回放时 Rust 读文件转 base64；气泡显示缩略图，输入栏 + 号选图（相册/拍照）
- **导出分享**：`share.dart`——导出 Markdown（角色分段 + 图片占位）/ 分享长图（离屏 RepaintBoundary → PNG），系统分享面板（share_plus 12 用 `SharePlus.instance.share(ShareParams...)`，旧 `Share.shareXFiles` 已废弃）
- **错误降噪**：桥接公开函数从 anyhow 改为 `Result<T, BridgeError>`（Display 只含错误链）；init_app 里 `RUST_BACKTRACE=0`（anyhow 的 backtrace 捕获由它控制）

## 踩坑
- **frb 不支持 `Result<T, String>`**（String 不满足 std::error::Error bound），也不认裸类型别名——用 `Result<T, BridgeError>`，BridgeError 实现 std Error + Display。
- **仿真器相册选图**：`adb push` 到 Pictures/ 不会被 MediaStore 索引（photo picker 看不到）；用 `input keyevent 120`（KEYCODE_SYSRQ 系统截图）自动索引到 Pictures/Screenshots/，picker 里可选。
- **分享长图离屏渲染**末尾 bottom overflow 1.3px——transcript 末尾加 4px 留白。
- ChatMessage 加字段后全仓字面量连锁报错，用 `ChatMessage::text(role, content)` helper 收敛。

## 待办（M5b）
主题切换、i18n（gen-l10n 中英）、用量统计页、图标启动屏、Release 打包（签名需用户生成 keystore）。
