import 'package:flutter/material.dart';
import 'package:quinhub/bridge/api/echo.dart';
import 'package:quinhub/bridge/frb_generated.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const QuinHubEchoApp());
}

class QuinHubEchoApp extends StatelessWidget {
  const QuinHubEchoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuinHub M1 Echo',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const EchoPage(),
    );
  }
}

class EchoPage extends StatefulWidget {
  const EchoPage({super.key});

  @override
  State<EchoPage> createState() => _EchoPageState();
}

class _EchoPageState extends State<EchoPage> {
  final _controller = TextEditingController(text: '你好，QuinHub');
  final StringBuffer _output = StringBuffer();
  bool _streaming = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final input = _controller.text;
    if (input.isEmpty || _streaming) return;
    setState(() {
      _output.clear();
      _streaming = true;
    });
    try {
      await for (final chunk in echoStream(input: input)) {
        setState(() => _output.write(chunk));
      }
    } catch (e) {
      setState(() => _output.write('\n[exception] $e'));
    } finally {
      if (mounted) setState(() => _streaming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QuinHub M1 · Echo 联调')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: '输入（经 Rust 核心回显）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _streaming ? null : _send,
              icon: Icon(_streaming ? Icons.hourglass_top : Icons.send),
              label: Text(_streaming ? '流式中…' : '发送'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _output.toString(),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
