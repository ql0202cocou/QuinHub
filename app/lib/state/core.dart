import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quinhub/bridge/api/lifecycle.dart';

/// 应用启动时初始化 Rust 核心：注入主密钥 + 打开数据库。
/// 主密钥存于平台 Keystore/Keychain（flutter_secure_storage），首次启动随机生成。
final coreInitProvider = FutureProvider<void>((ref) async {
  const secure = FlutterSecureStorage();
  var key = await secure.read(key: 'master_key');
  if (key == null) {
    final rnd = Random.secure();
    key = base64Encode(List<int>.generate(32, (_) => rnd.nextInt(256)));
    await secure.write(key: 'master_key', value: key);
  }
  final dir = await getApplicationDocumentsDirectory();
  await initCore(dbPath: '${dir.path}/quinhub.db', masterKeyB64: key);
});
