import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:markdown/markdown.dart' as md;

String spokenText(String markdown) {
  final nodes = md.Document().parseLines(markdown.split('\n'));
  String read(md.Node node) {
    if (node is md.Element) {
      if (node.tag == 'img') return node.attributes['alt'] ?? '';
      final text = (node.children ?? []).map(read).join();
      return ['p', 'h1', 'h2', 'h3', 'h4', 'li', 'pre', 'blockquote', 'br']
              .contains(node.tag)
          ? '$text\n'
          : text;
    }
    return node.textContent;
  }

  return nodes
      .map(read)
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

class ReadAloud extends StatefulWidget {
  const ReadAloud({super.key, required this.content, required this.language});
  final String content, language;
  @override
  State<ReadAloud> createState() => _ReadAloudState();
}

class _ReadAloudState extends State<ReadAloud> with WidgetsBindingObserver {
  FlutterTts? _tts;
  bool _playing = false, _starting = false;
  int _generation = 0;
  double _rate = 0.45;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_stop());
  }

  @override
  void didUpdateWidget(covariant ReadAloud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content ||
        oldWidget.language != widget.language) {
      unawaited(_stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    final tts = _tts;
    if (tts != null) {
      unawaited(tts.stop().then<void>((_) {}, onError: (Object _) {}));
    }
    super.dispose();
  }

  Future<void> _stop() async {
    _generation++;
    if (mounted) {
      setState(() {
        _playing = false;
        _starting = false;
      });
    }
    try {
      await _tts?.stop();
    } catch (_) {/* No engine may be installed. */}
  }

  Future<void> _speak() async {
    if (_playing || _starting) return;
    final run = ++_generation;
    setState(() => _starting = true);
    try {
      final tts = _tts ??= FlutterTts();
      await tts.awaitSpeakCompletion(true);
      final languages =
          (await tts.getLanguages as List).map((e) => e.toString()).toList();
      final prefix = switch (widget.language.toLowerCase()) {
        'en' || 'english' => ['en'],
        'fil' || 'tl' || 'filipino' || 'tagalog' => ['fil', 'tl'],
        'ilo' || 'ilocano' || 'ilokano' => ['ilo'],
        _ => [widget.language.toLowerCase().split('-').first],
      };
      final supported = languages.where((v) => prefix
          .contains(v.toLowerCase().replaceAll('_', '-').split('-').first));
      if (supported.isEmpty) {
        throw UnsupportedError('No voice for this language');
      }
      await tts.setLanguage(supported.first);
      await tts.setSpeechRate(_rate);
      if (!mounted || run != _generation) return;
      setState(() {
        _starting = false;
        _playing = true;
      });
      final text = spokenText(widget.content);
      // Bound utterances to stay within native engine input limits.
      for (var start = 0; start < text.length;) {
        var end = (start + 2500).clamp(0, text.length);
        if (end < text.length) {
          final space = text.lastIndexOf(' ', end);
          if (space > start) end = space;
        }
        if (!mounted || run != _generation) return;
        final result = await tts.speak(text.substring(start, end));
        if (result != 1) throw StateError('Speech failed');
        start = end;
      }
    } catch (_) {
      if (mounted && run == _generation) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Read aloud is unavailable. Install a text-to-speech voice for this material’s language in your device settings.')));
      }
    } finally {
      if (mounted && run == _generation) {
        setState(() {
          _playing = false;
          _starting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton.icon(
            onPressed: widget.content.trim().isEmpty
                ? null
                : (_playing || _starting)
                    ? _stop
                    : _speak,
            icon: Icon(
                _playing || _starting ? Icons.stop : Icons.volume_up_outlined),
            label: Text(_playing || _starting ? 'Stop reading' : 'Read aloud'),
          ),
          DropdownButton<double>(
            value: _rate,
            onChanged: _playing || _starting
                ? null
                : (v) => setState(() => _rate = v!),
            items: const [
              DropdownMenuItem(value: 0.3, child: Text('Slow')),
              DropdownMenuItem(value: 0.45, child: Text('Normal')),
              DropdownMenuItem(value: 0.6, child: Text('Fast')),
            ],
          ),
        ],
      );
}
