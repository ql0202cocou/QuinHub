// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'QuinHub';

  @override
  String get settings => 'Settings';

  @override
  String get providers => 'Providers';

  @override
  String get providersSubtitle =>
      'API keys & models for OpenAI-compatible / Anthropic';

  @override
  String get appearance => 'Appearance';

  @override
  String get language => 'Language';

  @override
  String get followSystem => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get about => 'About QuinHub';

  @override
  String get noConversations => 'No conversations yet — tap the button below';

  @override
  String get noProvidersGuide => 'Add a provider (API key) to start chatting';

  @override
  String get configureProviders => 'Configure providers';

  @override
  String get addProviderFirst => 'Add a provider in Settings first';

  @override
  String noEnabledModels(String name) {
    return '\"$name\" has no enabled models — edit, test, and select';
  }

  @override
  String get unnamedConversation => 'Untitled';

  @override
  String get pin => 'Pin';

  @override
  String get unpin => 'Unpin';

  @override
  String get rename => 'Rename';

  @override
  String get renameConversation => 'Rename conversation';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get saving => 'Saving…';

  @override
  String deleteConversationTitle(String title) {
    return 'Delete \"$title\"?';
  }

  @override
  String get deleteConversationContent =>
      'All messages in this conversation will be deleted.';

  @override
  String deleteProviderTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get deleteProviderContent =>
      'Linked conversations are kept but can\'t continue.';

  @override
  String get noProviders => 'No providers yet — tap + to add';

  @override
  String get addProvider => 'Add provider';

  @override
  String get editProvider => 'Edit provider';

  @override
  String get fieldName => 'Name';

  @override
  String get fieldType => 'Type';

  @override
  String get fieldBaseUrl => 'Base URL';

  @override
  String get fieldApiKey => 'API Key';

  @override
  String get apiKeyKeepUnchanged => 'API Key (leave empty to keep)';

  @override
  String get fieldRequired => 'Required';

  @override
  String get setDefault => 'Set as default';

  @override
  String get testConnection => 'Test connection';

  @override
  String get saveBeforeTest => 'Save to enable testing';

  @override
  String connectSuccess(int count) {
    return 'Connected — $count models found';
  }

  @override
  String get connectFailed => 'Connection failed';

  @override
  String get acknowledge => 'OK';

  @override
  String get enableModelsHint => 'Enabled models (save to apply)';

  @override
  String get openaiCompatible => 'OpenAI-compatible';

  @override
  String loadFailed(String error) {
    return 'Load failed: $error';
  }

  @override
  String saveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String initFailed(String error) {
    return 'Init failed: $error';
  }

  @override
  String get retry => 'Retry';

  @override
  String get newChat => 'New chat';

  @override
  String get inputHint => 'Type a message…';

  @override
  String get selectModel => 'Select model';

  @override
  String get more => 'More';

  @override
  String get exportMarkdown => 'Export Markdown';

  @override
  String get shareImage => 'Share as image';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get copiedCode => 'Code copied';

  @override
  String get regenerate => 'Regenerate';

  @override
  String get editResend => 'Edit & resend';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get gallery => 'Gallery';

  @override
  String get camera => 'Camera';

  @override
  String get usageStats => 'Usage';

  @override
  String usageMessages(int count) {
    return 'Messages: $count';
  }

  @override
  String usageTokensIn(int count) {
    return 'Input tokens: $count';
  }

  @override
  String usageTokensOut(int count) {
    return 'Output tokens: $count';
  }

  @override
  String shareFailed(String error) {
    return 'Failed to create share image: $error';
  }

  @override
  String get exportedBy => 'Exported by QuinHub';

  @override
  String imageCount(int count) {
    return '[image ×$count]';
  }

  @override
  String get send => 'Send';

  @override
  String get conversation => 'Conversation';

  @override
  String get user => 'User';

  @override
  String get assistant => 'Assistant';
}
