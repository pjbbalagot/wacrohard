import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/providers.dart';
import '../../core/strings.dart';
import '../../data/sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'read_aloud.dart';
import '../catalog/material_actions.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.resource});
  final Map<String, Object?> resource;
  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  double font = 16;
  String appearance = 'light';
  ScrollController? controller;
  bool initialized = false;
  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> initialize() async {
    if (initialized) return;
    initialized = true;
    final savedAppearance =
        await ref.read(storeProvider).preference('reading_appearance');
    if (!mounted) return;
    if (['light', 'sepia', 'dark'].contains(savedAppearance)) {
      appearance = savedAppearance!;
    }
    final saved = await ref
        .read(storeProvider)
        .progressFor(widget.resource['id'] as String);
    if (!mounted) return;
    controller = ScrollController(
        initialScrollOffset: (saved?['position'] as int?)?.toDouble() ?? 0);
    if ((widget.resource['content'] as String).trim().isNotEmpty) {
      final client = ref.read(supabaseClientProvider);
      final owner = await ref
          .read(storeProvider)
          .approvedAccountId(client?.auth.currentUser?.id);
      await ref.read(storeProvider).saveProgress(
          widget.resource['id'] as String,
          (saved?['position'] as int?) ?? 0,
          (saved?['percent'] as num?)?.toDouble() ?? 0,
          ownerUserId: owner);
      if (mounted && client != null) {
        unawaited(SyncService.syncIfConsented(ref.read(storeProvider), client));
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resource;
    final t = T(ref.watch(languageProvider));
    initialize();
    final dark = appearance == 'dark';
    final base = Theme.of(context);
    final background = dark
        ? const Color(0xFF121B2A)
        : appearance == 'sepia'
            ? const Color(0xFFFFF4DF)
            : Colors.white;
    final readerTheme = (dark
            ? ThemeData.dark(useMaterial3: true).copyWith(
                textTheme: base.textTheme
                    .apply(bodyColor: Colors.white, displayColor: Colors.white))
            : base)
        .copyWith(
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
          backgroundColor: background,
          foregroundColor: dark ? Colors.white : const Color(0xFF142D51),
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
              fontFamily: base.textTheme.titleLarge?.fontFamily,
              color: dark ? Colors.white : const Color(0xFF142D51),
              fontSize: 18,
              fontWeight: FontWeight.w700)),
    );
    return Theme(
        data: readerTheme,
        child: Scaffold(
          appBar: AppBar(title: Text(r['title'] as String), actions: [
            if (canDeleteMaterial(r))
              IconButton(
                tooltip: 'Delete generated material',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await deleteMaterial(context, ref, r) &&
                      context.mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
            IconButton(
                tooltip: t.call('text_size'),
                icon: const Icon(Icons.text_fields),
                onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => StatefulBuilder(
                        builder: (c, set) => Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(t.call('text_size')),
                                  Slider(
                                      min: 14,
                                      max: 28,
                                      value: font,
                                      onChanged: (v) {
                                        set(() => font = v);
                                        setState(() {});
                                      })
                                ]))))),
            PopupMenuButton<String>(
              tooltip: t.call('appearance'),
              initialValue: appearance,
              icon: Icon(
                  dark ? Icons.dark_mode_rounded : Icons.light_mode_outlined),
              onSelected: (value) {
                setState(() => appearance = value);
                unawaited(ref
                    .read(storeProvider)
                    .setPreference('reading_appearance', value));
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'light', child: Text('Light')),
                PopupMenuItem(value: 'sepia', child: Text('Sepia')),
                PopupMenuItem(value: 'dark', child: Text('Dark')),
              ],
            ),
          ]),
          body: controller == null
              ? const Center(child: CircularProgressIndicator())
              : (r['content'] as String).trim().isEmpty
                  ? _externalOnly(r)
                  : Container(
                      color: background,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n is ScrollEndNotification &&
                              n.metrics.maxScrollExtent > 0) {
                            final pct = (n.metrics.pixels /
                                    n.metrics.maxScrollExtent *
                                    100)
                                .clamp(0, 100)
                                .toDouble();
                            unawaited(() async {
                              if (!mounted) return;
                              final client = ref.read(supabaseClientProvider);
                              final owner = await ref
                                  .read(storeProvider)
                                  .approvedAccountId(
                                      client?.auth.currentUser?.id);
                              await ref.read(storeProvider).saveProgress(
                                  r['id'] as String,
                                  n.metrics.pixels.toInt(),
                                  pct,
                                  ownerUserId: owner);
                              if (mounted && client != null) {
                                unawaited(SyncService.syncIfConsented(
                                    ref.read(storeProvider), client));
                              }
                            }());
                          }
                          return false;
                        },
                        child: Markdown(
                            data: r['content'] as String,
                            controller: controller,
                            selectable: true,
                            padding: const EdgeInsets.all(20),
                            styleSheet:
                                MarkdownStyleSheet.fromTheme(readerTheme)
                                    .copyWith(
                                        p: p(font),
                                        h1: p(font + 8),
                                        h2: p(font + 5),
                                        h3: p(font + 3))),
                      )),
          bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if ((r['content'] as String).trim().isNotEmpty)
                      ReadAloud(
                          content: r['content'] as String,
                          language: r['language'] as String),
                    if (r['content_type'] == 'ai_generated')
                      const Text(
                          'AI-GENERATED AND UNVERIFIED — check accuracy and reuse rights before relying on or sharing this material.',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    if (r['content_type'] == 'translation')
                      Text(
                          'Translation: ${r['source_language']} → ${r['language']} • ${r['translation_method'] == 'machine' ? 'Machine-translated' : 'Human-translated'} • ${r['translation_review_status']}'),
                    if (r['content_type'] != 'ai_generated' &&
                        r['content_type'] != 'translation')
                      Text(
                          'TULAI review status: ${r['review_status'] ?? 'not reviewed'}'),
                    Text(
                        '${t.call('source')}: ${r['source_name']}  •  ${t.call('license')}: ${r['license']}',
                        style: readerTheme.textTheme.bodySmall,
                        textAlign: TextAlign.center),
                  ]))),
        ));
  }

  Widget _externalOnly(Map<String, Object?> resource) {
    final url =
        (resource['external_url'] ?? resource['source_url'])?.toString();
    return Center(
        child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.open_in_new, size: 48),
              const SizedBox(height: 12),
              const Text(
                  'This material is hosted by its original publisher and is not packaged for offline redistribution.'),
              if (url != null && url.isNotEmpty) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                    onPressed: () async {
                      final uri = Uri.tryParse(url);
                      if (uri != null &&
                          (uri.scheme == 'https' || uri.scheme == 'http')) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open official source')),
              ] else
                const Text(
                    'The publisher has not supplied an accessible link.'),
            ])));
  }

  TextStyle p(double s) => TextStyle(
      fontSize: s,
      height: 1.65,
      color: appearance == 'dark' ? Colors.white : const Color(0xFF142D51));
}
