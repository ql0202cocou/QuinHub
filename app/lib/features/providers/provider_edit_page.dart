import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quinhub/bridge/api/profile.dart';
import 'package:quinhub/state/profiles.dart';

const _defaultBaseUrls = {
  'openai_compatible': 'https://api.openai.com/v1',
  'anthropic': 'https://api.anthropic.com',
};

/// 提供商编辑页（profileId = "new" 表示新建）。
class ProviderEditPage extends ConsumerStatefulWidget {
  const ProviderEditPage({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<ProviderEditPage> createState() => _ProviderEditPageState();
}

class _ProviderEditPageState extends ConsumerState<ProviderEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _baseUrl = TextEditingController();
  final _apiKey = TextEditingController();
  String _type = 'openai_compatible';
  bool _isDefault = false;
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  List<String>? _testedModels;
  Set<String> _selectedModels = {};

  bool get _isNew => widget.profileId == 'new';

  @override
  void initState() {
    super.initState();
    if (_isNew) {
      _baseUrl.text = _defaultBaseUrls[_type]!;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final p = await profileGet(id: widget.profileId);
      if (!mounted) return;
      setState(() {
        _name.text = p.name;
        _type = p.providerType;
        _baseUrl.text = p.baseUrl;
        _isDefault = p.isDefault;
        _selectedModels = p.enabledModels.toSet();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('加载失败：$e')));
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  void _onTypeChanged(String? v) {
    if (v == null) return;
    setState(() {
      // 当前 baseUrl 为空或仍是另一类型的默认值时，跟随新类型
      final others = _defaultBaseUrls.values.toSet()
        ..remove(_defaultBaseUrls[v]);
      if (_baseUrl.text.isEmpty || others.contains(_baseUrl.text)) {
        _baseUrl.text = _defaultBaseUrls[v]!;
      }
      _type = v;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_isNew) {
        await profileCreate(
          name: _name.text.trim(),
          providerType: _type,
          baseUrl: _baseUrl.text.trim(),
          apiKey: _apiKey.text,
          isDefault: _isDefault,
        );
      } else {
        await profileUpdate(
          id: widget.profileId,
          name: _name.text.trim(),
          baseUrl: _baseUrl.text.trim(),
          apiKey: _apiKey.text.isEmpty ? null : _apiKey.text,
          isDefault: _isDefault,
          enabledModels: _selectedModels.toList(),
        );
      }
      await ref.read(profilesProvider.notifier).reload();
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testedModels = null;
    });
    try {
      final models = await profileTest(id: widget.profileId);
      if (!mounted) return;
      setState(() => _testedModels = models);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('连接成功，发现 ${models.length} 个模型')));
    } catch (e) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('连接失败'),
          content: Text('$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? '添加提供商' : '编辑提供商')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: '名称',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? '必填' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(
                      labelText: '类型',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'openai_compatible',
                        child: Text('OpenAI 兼容接口'),
                      ),
                      DropdownMenuItem(
                        value: 'anthropic',
                        child: Text('Anthropic'),
                      ),
                    ],
                    onChanged: _onTypeChanged,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _baseUrl,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? '必填' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _apiKey,
                    decoration: InputDecoration(
                      labelText: _isNew ? 'API Key' : 'API Key（留空则不修改）',
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: true,
                    enableSuggestions: false,
                    autocorrect: false,
                    validator: (v) =>
                        _isNew && (v == null || v.isEmpty) ? '必填' : null,
                  ),
                  SwitchListTile(
                    title: const Text('设为默认'),
                    value: _isDefault,
                    onChanged: (v) => setState(() => _isDefault = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (_isNew || _testing || _saving)
                              ? null
                              : _test,
                          icon: _testing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.wifi_tethering),
                          label: Text(_isNew ? '保存后可测试连接' : '测试连接'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: (_saving || _testing) ? null : _save,
                          icon: const Icon(Icons.check),
                          label: Text(_saving ? '保存中…' : '保存'),
                        ),
                      ),
                    ],
                  ),
                  if (_testedModels != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      '启用模型（勾选后保存生效）',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    ..._testedModels!.map(
                      (m) => CheckboxListTile(
                        dense: true,
                        title: Text(m, style: const TextStyle(fontSize: 14)),
                        value: _selectedModels.contains(m),
                        onChanged: (v) => setState(() {
                          if (v ?? false) {
                            _selectedModels.add(m);
                          } else {
                            _selectedModels.remove(m);
                          }
                        }),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
