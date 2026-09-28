// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'QuinHub';

  @override
  String get settings => '设置';

  @override
  String get providers => '模型提供商';

  @override
  String get providersSubtitle => 'OpenAI 兼容 / Anthropic 的 Key 与模型';

  @override
  String get appearance => '外观';

  @override
  String get language => '语言';

  @override
  String get followSystem => '跟随系统';

  @override
  String get light => '浅色';

  @override
  String get dark => '深色';

  @override
  String get about => '关于 QuinHub';

  @override
  String get noConversations => '还没有会话，点右下角开始';

  @override
  String get noProvidersGuide => '先添加一个模型提供商（API Key）开始对话';

  @override
  String get configureProviders => '配置提供商';

  @override
  String get addProviderFirst => '先去设置里添加一个模型提供商';

  @override
  String noEnabledModels(String name) {
    return '「$name」还没启用模型，点编辑测试并勾选';
  }

  @override
  String get unnamedConversation => '未命名会话';

  @override
  String get pin => '置顶';

  @override
  String get unpin => '取消置顶';

  @override
  String get rename => '重命名';

  @override
  String get renameConversation => '重命名会话';

  @override
  String get edit => '编辑';

  @override
  String get delete => '删除';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get saving => '保存中…';

  @override
  String deleteConversationTitle(String title) {
    return '删除「$title」？';
  }

  @override
  String get deleteConversationContent => '会话内消息将一并删除。';

  @override
  String deleteProviderTitle(String name) {
    return '删除「$name」？';
  }

  @override
  String get deleteProviderContent => '关联会话将保留，但无法继续对话。';

  @override
  String get noProviders => '还没有提供商，点右下角添加';

  @override
  String get addProvider => '添加提供商';

  @override
  String get editProvider => '编辑提供商';

  @override
  String get fieldName => '名称';

  @override
  String get fieldType => '类型';

  @override
  String get fieldBaseUrl => 'Base URL';

  @override
  String get fieldApiKey => 'API Key';

  @override
  String get apiKeyKeepUnchanged => 'API Key（留空则不修改）';

  @override
  String get fieldRequired => '必填';

  @override
  String get setDefault => '设为默认';

  @override
  String get testConnection => '测试连接';

  @override
  String get saveBeforeTest => '保存后可测试连接';

  @override
  String connectSuccess(int count) {
    return '连接成功，发现 $count 个模型';
  }

  @override
  String get connectFailed => '连接失败';

  @override
  String get acknowledge => '知道了';

  @override
  String get enableModelsHint => '启用模型（勾选后保存生效）';

  @override
  String get openaiCompatible => 'OpenAI 兼容接口';

  @override
  String loadFailed(String error) {
    return '加载失败：$error';
  }

  @override
  String saveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String initFailed(String error) {
    return '初始化失败：$error';
  }

  @override
  String get retry => '重试';

  @override
  String get newChat => '新会话';

  @override
  String get inputHint => '输入消息…';

  @override
  String get selectModel => '选模型';

  @override
  String get more => '更多';

  @override
  String get exportMarkdown => '导出 Markdown';

  @override
  String get shareImage => '分享长图';

  @override
  String get copy => '复制';

  @override
  String get copied => '已复制';

  @override
  String get copiedCode => '已复制代码';

  @override
  String get regenerate => '重新生成';

  @override
  String get editResend => '编辑并重发';

  @override
  String get cancelled => '已取消';

  @override
  String get unknownError => '未知错误';

  @override
  String get gallery => '相册';

  @override
  String get camera => '拍照';

  @override
  String get usageStats => '用量统计';

  @override
  String usageMessages(int count) {
    return '消息数：$count';
  }

  @override
  String usageTokensIn(int count) {
    return '输入 tokens：$count';
  }

  @override
  String usageTokensOut(int count) {
    return '输出 tokens：$count';
  }

  @override
  String shareFailed(String error) {
    return '生成分享图失败：$error';
  }

  @override
  String get exportedBy => '由 QuinHub 导出';

  @override
  String imageCount(int count) {
    return '[图片×$count]';
  }

  @override
  String get send => '发送';

  @override
  String get conversation => '会话';

  @override
  String get user => '用户';

  @override
  String get assistant => '助手';

  @override
  String get archive => '归档';

  @override
  String get unarchive => '取消归档';

  @override
  String get archivedConversations => '已归档会话';

  @override
  String get noArchivedConversations => '没有已归档会话';

  @override
  String get defaultModel => '默认模型';

  @override
  String get defaultModelUnset => '未设置（跟随默认提供商）';

  @override
  String get conversationParams => '会话参数';

  @override
  String get maxTokens => '最大 Tokens';

  @override
  String get maxTokensHint => '留空使用默认（4096）';

  @override
  String get systemPrompt => '系统提示词';

  @override
  String get resetToDefault => '重置为默认';

  @override
  String get modelNoVision => '当前模型不支持图片输入';
}
