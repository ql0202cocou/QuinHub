import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quinhub/bridge/api/profile.dart';
import 'package:quinhub/state/core.dart';

/// Provider 配置列表。所有变更后调用 reload 重新拉取。
class ProfilesNotifier extends AsyncNotifier<List<ProfileDto>> {
  @override
  Future<List<ProfileDto>> build() async {
    await ref.watch(coreInitProvider.future); // 等 Rust 核心初始化
    return profileList();
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(profileList);
  }

  Future<void> remove(String id) async {
    await profileDelete(id: id);
    await reload();
  }
}

final profilesProvider =
    AsyncNotifierProvider<ProfilesNotifier, List<ProfileDto>>(
      ProfilesNotifier.new,
    );
