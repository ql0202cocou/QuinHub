import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quinhub/bridge/api/message.dart';
import 'package:share_plus/share_plus.dart';
import 'package:quinhub/l10n/app_localizations.dart';
import 'package:quinhub/theme/tokens.dart';
import 'package:quinhub/ui/lobe_tag.dart';

/// 导出会话为 Markdown 文件并调系统分享。
Future<void> exportMarkdown(
  String title,
  List<MessageDto> messages,
  AppLocalizations l10n,
) async {
  final buf = StringBuffer('# ${title.isEmpty ? l10n.newChat : title}\n\n');
  for (final m in messages) {
    if (m.status != 'done') continue;
    final who = switch (m.role) {
      'user' => '**${l10n.user}**',
      'assistant' =>
        '**${l10n.assistant}**${m.model != null ? "（${m.model}）" : ""}',
      _ => '**${m.role}**',
    };
    buf.writeln('$who：\n');
    for (var _ in m.images) {
      buf.writeln('${l10n.imageCount(1)}\n');
    }
    buf.writeln(m.text);
    buf.writeln('\n---\n');
  }
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/quinhub-export.md');
  await f.writeAsString(buf.toString());
  await SharePlus.instance.share(
    ShareParams(files: [XFile(f.path)], subject: title),
  );
}

/// 分享长图：离屏渲染紧凑对话 → PNG → 系统分享。
Future<void> shareAsImage(
  BuildContext context,
  String title,
  List<MessageDto> messages,
  AppLocalizations l10n,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final boundaryKey = GlobalKey();
  final overlay = Overlay.of(context);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => Center(
      child: Material(
        child: RepaintBoundary(
          key: boundaryKey,
          child: Container(
            width: 560,
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: _Transcript(title: title, messages: messages),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    // 等离屏渲染完成
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/quinhub-share.png');
    await f.writeAsBytes(bytes.buffer.asUint8List());
    await SharePlus.instance.share(
      ShareParams(files: [XFile(f.path)], subject: title),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.shareFailed('$e'))));
  } finally {
    entry.remove();
  }
}

/// 离屏渲染用的紧凑对话视图（图片以占位符代替）。
/// 导出图固定白底，色值取 LobeTokens.light 而非跟随 App 主题。
class _Transcript extends StatelessWidget {
  const _Transcript({required this.title, required this.messages});

  final String title;
  final List<MessageDto> messages;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = LobeTokens.light;
    final done = messages.where((m) => m.status == 'done').toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.isEmpty ? l10n.newChat : title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: t.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.exportedBy,
          style: TextStyle(color: t.textTertiary, fontSize: 12),
        ),
        Divider(height: 24, color: t.borderSecondary),
        for (final m in done) ...[
          Row(
            children: [
              LobeTag(
                text: switch (m.role) {
                  'user' => l10n.user,
                  'assistant' => m.model ?? l10n.assistant,
                  _ => m.role,
                },
                color: m.role == 'user' ? t.info : t.textTertiary,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text(
              [
                if (m.images.isNotEmpty) l10n.imageCount(m.images.length),
                m.text,
              ].join('\n').trim(),
              style: TextStyle(fontSize: 14, height: 1.5, color: t.text),
            ),
          ),
        ],
        // 底部留白，避免离屏渲染 bottom overflow（M5a 实测 1.3px）
        const SizedBox(height: 4),
      ],
    );
  }
}
