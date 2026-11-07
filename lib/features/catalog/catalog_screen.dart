import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/brand_theme.dart';
import '../../core/strings.dart';
import '../reader/reader_screen.dart';
import 'material_actions.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key, this.recommended = false});
  final bool recommended;
  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  String query = '', subject = 'All', difficulty = 'All';
  final _search = TextEditingController();
  late Future<List<Map<String, Object?>>> _items;
  @override
  void initState() {
    super.initState();
    _items = loadItems();
    ref.read(repositoryProvider).refreshCatalogue().then((_) {
      if (mounted) reload();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<Map<String, Object?>>> loadItems() async {
    final repo = ref.read(repositoryProvider);
    final language = ref.read(contentLanguageProvider);
    final filtered = await repo.resources(
        query: query,
        subject: subject,
        language: language,
        difficulty: difficulty == 'All' ? null : difficulty);
    if (!widget.recommended) return filtered;
    final recommended = await repo.recommendations(language: language);
    final ids = recommended.map((r) => r['id']).toSet();
    return filtered.where((r) => ids.contains(r['id'])).toList();
  }

  void reload() => setState(() {
        _items = loadItems();
      });
  @override
  Widget build(BuildContext context) {
    ref.listen<String>(contentLanguageProvider, (previous, next) => reload());
    final language = ref.watch(contentLanguageProvider);
    final t = T(ref.watch(languageProvider));
    return Scaffold(
      appBar: AppBar(
          title: Text(
              widget.recommended ? t.call('recommend') : t.call('catalog'))),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              TextField(
                  controller: _search,
                  decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: t.call('search'),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 17),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide:
                              const BorderSide(color: Color(0xFFDCE5F3))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide:
                              const BorderSide(color: Brand.navy, width: 1.5))),
                  onChanged: (v) {
                    query = v;
                    reload();
                  }),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: DropdownButtonFormField<String>(
                        key: ValueKey('subject-$subject'),
                        initialValue: subject,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Brand.navy),
                        borderRadius: BorderRadius.circular(18),
                        decoration:
                            InputDecoration(labelText: t.call('subject')),
                        items: [
                          DropdownMenuItem(
                              value: 'All', child: Text(t.call('all'))),
                          const DropdownMenuItem(
                              value: 'Mathematics', child: Text('Mathematics')),
                          const DropdownMenuItem(
                              value: 'English', child: Text('English')),
                          const DropdownMenuItem(
                              value: 'Digital Skills',
                              child: Text('Digital Skills'))
                        ],
                        onChanged: (v) {
                          subject = v ?? 'All';
                          reload();
                        })),
                const SizedBox(width: 10),
                Expanded(
                    child: DropdownButtonFormField<String>(
                        key: ValueKey('difficulty-$difficulty'),
                        initialValue: difficulty,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            color: Brand.navy),
                        borderRadius: BorderRadius.circular(18),
                        decoration:
                            InputDecoration(labelText: t.call('difficulty')),
                        items: [
                          DropdownMenuItem(
                              value: 'All', child: Text(t.call('all'))),
                          ...[
                            'Beginner',
                            'Developing',
                            'Intermediate',
                            'Proficient'
                          ].map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)))
                        ],
                        onChanged: (v) {
                          difficulty = v ?? 'All';
                          reload();
                        })),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Text('${t.call('language')}: '),
                Text({
                      'all': t.call('all_languages'),
                      'en': 'English',
                      'fil': 'Filipino',
                      'ilo': 'Ilocano'
                    }[language] ??
                    'English')
              ]),
              if (query.isNotEmpty || subject != 'All' || difficulty != 'All')
                TextButton.icon(
                    onPressed: () {
                      _search.clear();
                      query = '';
                      subject = 'All';
                      difficulty = 'All';
                      reload();
                    },
                    icon: const Icon(Icons.filter_alt_off),
                    label: const Text('Clear filters')),
            ])),
        Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
                future: _items,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                                'Unable to load local lessons: ${snapshot.error}')));
                  }
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return Center(child: Text(t.call('no_results')));
                  }
                  return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final r = items[i];
                        final generated = r['content_type'] == 'ai_generated';
                        final origin = switch (r['content_type']) {
                          'official_source' => 'Official-source material',
                          'platform' => 'TULAI material',
                          'community' => 'Community material',
                          'ai_generated' => 'AI-generated • unverified',
                          'translation' => 'Reviewed translation',
                          _ => 'Learning material',
                        };
                        final availability =
                            (r['content'] as String).trim().isNotEmpty
                                ? 'Offline ready'
                                : 'Open source online';
                        final translation = r['content_type'] == 'translation'
                            ? ' • ${r['translation_method'] == 'machine' ? 'Machine' : 'Human'} translation reviewed'
                            : '';
                        final review = r['content_type'] == 'ai_generated'
                            ? 'AI-generated and unverified'
                            : 'Review: ${r['review_status'] ?? 'not reviewed'}';
                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () async {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          ReaderScreen(resource: r)));
                              if (mounted) reload();
                            },
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Container(
                                            padding: const EdgeInsets.all(11),
                                            decoration: BoxDecoration(
                                                color: generated
                                                    ? Brand.orange
                                                        .withValues(alpha: .12)
                                                    : Brand.blue
                                                        .withValues(alpha: .12),
                                                borderRadius:
                                                    BorderRadius.circular(14)),
                                            child: Icon(
                                                generated
                                                    ? Icons.auto_awesome_rounded
                                                    : Icons.menu_book_rounded,
                                                size: 23,
                                                color: generated
                                                    ? const Color(0xFFBF5700)
                                                    : Brand.navy)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: Text(r['title'] as String,
                                                style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    color: Brand.ink))),
                                        if (canDeleteMaterial(r))
                                          IconButton(
                                            tooltip:
                                                'Delete generated material',
                                            icon: const Icon(
                                                Icons.delete_outline,
                                                size: 21),
                                            onPressed: () async {
                                              if (await deleteMaterial(
                                                      context, ref, r) &&
                                                  mounted) reload();
                                            },
                                          )
                                        else
                                          const Icon(
                                              Icons.chevron_right_rounded,
                                              size: 21,
                                              color: Brand.muted),
                                      ]),
                                      const SizedBox(height: 12),
                                      Text(
                                          '${r['subject']} • ${r['difficulty']} • ${r['language']}',
                                          style: const TextStyle(
                                              color: Brand.muted,
                                              fontSize: 12)),
                                      const SizedBox(height: 7),
                                      Text(
                                          generated
                                              ? origin
                                              : '$origin$translation • $review',
                                          style: TextStyle(
                                              color: generated
                                                  ? const Color(0xFFAA4B00)
                                                  : Brand.muted,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 7),
                                      Row(children: [
                                        Icon(
                                            availability == 'Offline ready'
                                                ? Icons.offline_pin_outlined
                                                : Icons.open_in_new_rounded,
                                            size: 13,
                                            color: Brand.muted),
                                        const SizedBox(width: 5),
                                        Text(availability,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Brand.muted))
                                      ]),
                                    ])),
                          ),
                        );
                      });
                })),
      ]),
    );
  }
}
