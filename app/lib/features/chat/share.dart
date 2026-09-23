import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quinhub/bridge/api/message.dart';
import 'package:share_plus/share_plus.dart';

/// 导出会话为 Markdown 文件并调系统分享。
Future<void> exportMarkdown(String title, List<MessageDto> messages) async {
  final buf = StringBuffer('# ${title.isEmpty ? "QuinHub 会话" : title}\n\n');
  for (final m in messages) {
    if (m.status != 'done') continue;
    final who = switch (m.role) {
      'user' => '**用户**',
      'assistant' => '**助手**${m.model != null ? "（${m.model}）" : ""}',
      _ => '**${m.role}**',
    };
    buf.writeln('$who：\n');
    for (var _ in m.images) {
      buf.writeln('[图片]\n');
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
    messenger.showSnackBar(SnackBar(content: Text('生成分享图失败：$e')));
  } finally {
    entry.remove();
  }
}

/// 离屏渲染用的紧凑对话视图（图片以占位符代替）。
class _Transcript extends StatelessWidget {
  const _Transcript({required this.title, required this.messages});

  final String title;
  final List<MessageDto> messages;

  @override
  Widget build(BuildContext context) {
    final done = messages.where((m) => m.status == 'done').toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.isEmpty ? 'QuinHub 会话' : title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          '由 QuinHub 导出',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const Divider(height: 24),
        for (final m in done) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: m.role == 'user'
                      ? Colors.blue.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  switch (m.role) {
                    'user' => '用户',
                    'assistant' => m.model ?? '助手',
                    _ => m.role,
                  },
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text(
              [
                if (m.images.isNotEmpty) '[图片×${m.images.length}]',
                m.text,
              ].join('\n').trim(),
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
        ],
        // 底部留白，避免离屏渲染 bottom overflow（M5a 实测 1.3px）
        const SizedBox(height: 4),
      ],
    );
  }
}
