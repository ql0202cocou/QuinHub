import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'QuinHub'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @providers.
  ///
  /// In zh, this message translates to:
  /// **'模型提供商'**
  String get providers;

  /// No description provided for @providersSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'OpenAI 兼容 / Anthropic 的 Key 与模型'**
  String get providersSubtitle;

  /// No description provided for @appearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearance;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @followSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get followSystem;

  /// No description provided for @light.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get dark;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于 QuinHub'**
  String get about;

  /// No description provided for @noConversations.
  ///
  /// In zh, this message translates to:
  /// **'还没有会话，点右下角开始'**
  String get noConversations;

  /// No description provided for @noProvidersGuide.
  ///
  /// In zh, this message translates to:
  /// **'先添加一个模型提供商（API Key）开始对话'**
  String get noProvidersGuide;

  /// No description provided for @configureProviders.
  ///
  /// In zh, this message translates to:
  /// **'配置提供商'**
  String get configureProviders;

  /// No description provided for @addProviderFirst.
  ///
  /// In zh, this message translates to:
  /// **'先去设置里添加一个模型提供商'**
  String get addProviderFirst;

  /// No description provided for @noEnabledModels.
  ///
  /// In zh, this message translates to:
  /// **'「{name}」还没启用模型，点编辑测试并勾选'**
  String noEnabledModels(String name);

  /// No description provided for @unnamedConversation.
  ///
  /// In zh, this message translates to:
  /// **'未命名会话'**
  String get unnamedConversation;

  /// No description provided for @pin.
  ///
  /// In zh, this message translates to:
  /// **'置顶'**
  String get pin;

  /// No description provided for @unpin.
  ///
  /// In zh, this message translates to:
  /// **'取消置顶'**
  String get unpin;

  /// No description provided for @rename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get rename;

  /// No description provided for @renameConversation.
  ///
  /// In zh, this message translates to:
  /// **'重命名会话'**
  String get renameConversation;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @saving.
  ///
  /// In zh, this message translates to:
  /// **'保存中…'**
  String get saving;

  /// No description provided for @deleteConversationTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除「{title}」？'**
  String deleteConversationTitle(String title);

  /// No description provided for @deleteConversationContent.
  ///
  /// In zh, this message translates to:
  /// **'会话内消息将一并删除。'**
  String get deleteConversationContent;

  /// No description provided for @deleteProviderTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除「{name}」？'**
  String deleteProviderTitle(String name);

  /// No description provided for @deleteProviderContent.
  ///
  /// In zh, this message translates to:
  /// **'关联会话将保留，但无法继续对话。'**
  String get deleteProviderContent;

  /// No description provided for @noProviders.
  ///
  /// In zh, this message translates to:
  /// **'还没有提供商，点右下角添加'**
  String get noProviders;

  /// No description provided for @addProvider.
  ///
  /// In zh, this message translates to:
  /// **'添加提供商'**
  String get addProvider;

  /// No description provided for @editProvider.
  ///
  /// In zh, this message translates to:
  /// **'编辑提供商'**
  String get editProvider;

  /// No description provided for @fieldName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get fieldName;

  /// No description provided for @fieldType.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get fieldType;

  /// No description provided for @fieldBaseUrl.
  ///
  /// In zh, this message translates to:
  /// **'Base URL'**
  String get fieldBaseUrl;

  /// No description provided for @fieldApiKey.
  ///
  /// In zh, this message translates to:
  /// **'API Key'**
  String get fieldApiKey;

  /// No description provided for @apiKeyKeepUnchanged.
  ///
  /// In zh, this message translates to:
  /// **'API Key（留空则不修改）'**
  String get apiKeyKeepUnchanged;

  /// No description provided for @fieldRequired.
  ///
  /// In zh, this message translates to:
  /// **'必填'**
  String get fieldRequired;

  /// No description provided for @setDefault.
  ///
  /// In zh, this message translates to:
  /// **'设为默认'**
  String get setDefault;

  /// No description provided for @testConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get testConnection;

  /// No description provided for @saveBeforeTest.
  ///
  /// In zh, this message translates to:
  /// **'保存后可测试连接'**
  String get saveBeforeTest;

  /// No description provided for @connectSuccess.
  ///
  /// In zh, this message translates to:
  /// **'连接成功，发现 {count} 个模型'**
  String connectSuccess(int count);

  /// No description provided for @connectFailed.
  ///
  /// In zh, this message translates to:
  /// **'连接失败'**
  String get connectFailed;

  /// No description provided for @acknowledge.
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get acknowledge;

  /// No description provided for @enableModelsHint.
  ///
  /// In zh, this message translates to:
  /// **'启用模型（勾选后保存生效）'**
  String get enableModelsHint;

  /// No description provided for @openaiCompatible.
  ///
  /// In zh, this message translates to:
  /// **'OpenAI 兼容接口'**
  String get openaiCompatible;

  /// No description provided for @loadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败：{error}'**
  String loadFailed(String error);

  /// No description provided for @saveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败：{error}'**
  String saveFailed(String error);

  /// No description provided for @initFailed.
  ///
  /// In zh, this message translates to:
  /// **'初始化失败：{error}'**
  String initFailed(String error);

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @newChat.
  ///
  /// In zh, this message translates to:
  /// **'新会话'**
  String get newChat;

  /// No description provided for @inputHint.
  ///
  /// In zh, this message translates to:
  /// **'输入消息…'**
  String get inputHint;

  /// No description provided for @selectModel.
  ///
  /// In zh, this message translates to:
  /// **'选模型'**
  String get selectModel;

  /// No description provided for @more.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get more;

  /// No description provided for @exportMarkdown.
  ///
  /// In zh, this message translates to:
  /// **'导出 Markdown'**
  String get exportMarkdown;

  /// No description provided for @shareImage.
  ///
  /// In zh, this message translates to:
  /// **'分享长图'**
  String get shareImage;

  /// No description provided for @copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get copied;

  /// No description provided for @copiedCode.
  ///
  /// In zh, this message translates to:
  /// **'已复制代码'**
  String get copiedCode;

  /// No description provided for @regenerate.
  ///
  /// In zh, this message translates to:
  /// **'重新生成'**
  String get regenerate;

  /// No description provided for @editResend.
  ///
  /// In zh, this message translates to:
  /// **'编辑并重发'**
  String get editResend;

  /// No description provided for @cancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get cancelled;

  /// No description provided for @unknownError.
  ///
  /// In zh, this message translates to:
  /// **'未知错误'**
  String get unknownError;

  /// No description provided for @gallery.
  ///
  /// In zh, this message translates to:
  /// **'相册'**
  String get gallery;

  /// No description provided for @camera.
  ///
  /// In zh, this message translates to:
  /// **'拍照'**
  String get camera;

  /// No description provided for @usageStats.
  ///
  /// In zh, this message translates to:
  /// **'用量统计'**
  String get usageStats;

  /// No description provided for @usageMessages.
  ///
  /// In zh, this message translates to:
  /// **'消息数：{count}'**
  String usageMessages(int count);

  /// No description provided for @usageTokensIn.
  ///
  /// In zh, this message translates to:
  /// **'输入 tokens：{count}'**
  String usageTokensIn(int count);

  /// No description provided for @usageTokensOut.
  ///
  /// In zh, this message translates to:
  /// **'输出 tokens：{count}'**
  String usageTokensOut(int count);

  /// No description provided for @shareFailed.
  ///
  /// In zh, this message translates to:
  /// **'生成分享图失败：{error}'**
  String shareFailed(String error);

  /// No description provided for @exportedBy.
  ///
  /// In zh, this message translates to:
  /// **'由 QuinHub 导出'**
  String get exportedBy;

  /// No description provided for @imageCount.
  ///
  /// In zh, this message translates to:
  /// **'[图片×{count}]'**
  String imageCount(int count);

  /// No description provided for @send.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get send;

  /// No description provided for @conversation.
  ///
  /// In zh, this message translates to:
  /// **'会话'**
  String get conversation;

  /// No description provided for @user.
  ///
  /// In zh, this message translates to:
  /// **'用户'**
  String get user;

  /// No description provided for @assistant.
  ///
  /// In zh, this message translates to:
  /// **'助手'**
  String get assistant;

  /// No description provided for @archive.
  ///
  /// In zh, this message translates to:
  /// **'归档'**
  String get archive;

  /// No description provided for @unarchive.
  ///
  /// In zh, this message translates to:
  /// **'取消归档'**
  String get unarchive;

  /// No description provided for @archivedConversations.
  ///
  /// In zh, this message translates to:
  /// **'已归档会话'**
  String get archivedConversations;

  /// No description provided for @noArchivedConversations.
  ///
  /// In zh, this message translates to:
  /// **'没有已归档会话'**
  String get noArchivedConversations;

  /// No description provided for @defaultModel.
  ///
  /// In zh, this message translates to:
  /// **'默认模型'**
  String get defaultModel;

  /// No description provided for @defaultModelUnset.
  ///
  /// In zh, this message translates to:
  /// **'未设置（跟随默认提供商）'**
  String get defaultModelUnset;

  /// No description provided for @conversationParams.
  ///
  /// In zh, this message translates to:
  /// **'会话参数'**
  String get conversationParams;

  /// No description provided for @maxTokens.
  ///
  /// In zh, this message translates to:
  /// **'最大 Tokens'**
  String get maxTokens;

  /// No description provided for @maxTokensHint.
  ///
  /// In zh, this message translates to:
  /// **'留空使用默认（4096）'**
  String get maxTokensHint;

  /// No description provided for @systemPrompt.
  ///
  /// In zh, this message translates to:
  /// **'系统提示词'**
  String get systemPrompt;

  /// No description provided for @resetToDefault.
  ///
  /// In zh, this message translates to:
  /// **'重置为默认'**
  String get resetToDefault;

  /// No description provided for @modelNoVision.
  ///
  /// In zh, this message translates to:
  /// **'当前模型不支持图片输入'**
  String get modelNoVision;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
