# QuinHub 移动端 — 发布与合规 Checklist（M5 占位）

版本：v0.1（骨架，M5 逐项落实）

## 1. Android 发布
- [x] ~~生成 release keystore~~ → **待用户本人执行**（见下），不进仓库
- [ ] 配置 `key.properties`（本地）/ CI signing
- [x] 产出 AAB（Google Play）+ APK（直接分发）——M5b 已跑通 release APK（debug 签名占位）
- [x] targetSdk 满足 Google Play 当年要求（36）
- [x] 应用图标（自适应图标）与启动屏 —— M5b 完成（v0.1 占位图标，tools/gen_icon.py 可换设计稿重新生成）
- [ ] 若面向中国大陆安卓市场：**App 备案**（工信部）与各商店开发者资质

### 签名操作指引（用户本人执行）
```bash
# 1. 生成 keystore（密码自行保管，文件不要提交 git）
keytool -genkey -v -keystore ~/quinhub-release.keystore -keyalg RSA -keysize 2048 -validity 10000 -alias quinhub

# 2. 创建 app/android/key.properties（gitignore 已排除）：
#    storePassword=<密码> / keyPassword=<密码> / keyAlias=quinhub / storeFile=<keystore 绝对路径>

# 3. android/app/build.gradle.kts 的 release 块改读 keyProperties（模板注释已有 TODO）
```

## 2. iOS 发布
- [ ] Apple Developer 账号（$99/年）
- [ ] 证书与描述文件管理（CI 建议 App Store Connect API Key 或 fastlane match）
- [ ] macOS 构建通道（本地 Mac 或 CI macOS runner）——CI job 骨架已备（注释态）
- [ ] App Store Connect 应用信息、分级问卷

## 3. 合规与隐私（AI 应用必做）
- [ ] **隐私政策页面**（上架必需）：声明 Key 仅存本地设备、对话内容除直连用户所选 API 服务商外不出设备、不收集分析数据（如不接入崩溃收集需写明）
- [ ] App Store 审核：AI 生成内容类应用需说明内容来源与免责；BYOK 模式下用户自担 API 合规
- [ ] Google Play：数据安全表单（Data safety）填写
- [ ] 崩溃收集（若接入，如 Sentry）：单独决策，需在隐私政策中声明；默认不接入

## 4. 商店素材
- [ ] 应用图标（双端）
- [ ] 截图：Android（手机 5"~7" 多尺寸）、iOS（6.9" / 6.5" / iPad 如支持）
- [ ] 应用描述（中/英）、关键词
- [ ] 分享/预览图（可选）

## 5. 版本管理
- [ ] 语义化版本（major.minor.patch）+ build number
- [ ] CHANGELOG.md 维护（Keep a Changelog 格式）
- [ ] Git tag 与 release 对应
