import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/brand_theme.dart';
import '../../core/strings.dart';
import '../catalog/catalog_screen.dart';
import '../assessment/assessment_screen.dart';
import '../auth/auth_screen.dart';
import '../ai/ai_discovery_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int tab = 0;
  void refreshStatus() {
    if (!mounted) return;
    ref.invalidate(progressProvider);
    ref.invalidate(assessmentHistoryProvider);
    ref.invalidate(recentActivitiesProvider);
  }

  Future<void> preferences() async {
    final t = T(ref.read(languageProvider));
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => StatefulBuilder(
              builder: (context, setSheet) => Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20,
                      MediaQuery.of(context).viewInsets.bottom + 24),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(t.call('settings'),
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        Text(t.call('interface_language')),
                        DropdownButton<String>(
                            isExpanded: true,
                            value: ref.read(languageProvider),
                            items: const [
                              DropdownMenuItem(
                                  value: 'en', child: Text('English')),
                              DropdownMenuItem(
                                  value: 'fil', child: Text('Filipino')),
                              DropdownMenuItem(
                                  value: 'ilo', child: Text('Ilocano'))
                            ],
                            onChanged: (v) async {
                              if (v == null) return;
                              ref.read(languageProvider.notifier).state = v;
                              await ref
                                  .read(storeProvider)
                                  .setPreference('interface_language', v);
                              setSheet(() {});
                            }),
                        const SizedBox(height: 8),
                        Text(t.call('content_language')),
                        DropdownButton<String>(
                            isExpanded: true,
                            value: ref.read(contentLanguageProvider),
                            items: [
                              DropdownMenuItem(
                                  value: 'all',
                                  child: Text(t.call('all_languages'))),
                              DropdownMenuItem(
                                  value: 'en', child: Text('English')),
                              DropdownMenuItem(
                                  value: 'fil', child: Text('Filipino')),
                              DropdownMenuItem(
                                  value: 'ilo', child: Text('Ilocano'))
                            ],
                            onChanged: (v) async {
                              if (v == null) return;
                              ref.read(contentLanguageProvider.notifier).state =
                                  v;
                              await ref
                                  .read(storeProvider)
                                  .setPreference('content_language', v);
                              setSheet(() {});
                            }),
                      ])),
            ));
  }

  @override
  Widget build(BuildContext context) {
    final t = T(ref.watch(languageProvider));
    final progress = ref.watch(progressProvider);
    final history = ref.watch(assessmentHistoryProvider);
    final activities = ref.watch(recentActivitiesProvider);
    final latest = <String, Map<String, Object?>>{};
    for (final result in history.valueOrNull ?? <Map<String, Object?>>[]) {
      latest.putIfAbsent(result['subject'].toString(), () => result);
    }
    return Scaffold(
      appBar: AppBar(title: const BrandTitle(), actions: [
        IconButton(
            tooltip: t.call('settings'),
            onPressed: preferences,
            icon: const Icon(Icons.tune_rounded)),
        IconButton(
            tooltip: t.call('ai'),
            onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AiDiscoveryScreen()))
                .then((_) => refreshStatus()),
            icon: const Icon(Icons.auto_awesome_rounded, color: Brand.navy)),
        IconButton(
            tooltip: t.call('account'),
            onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()))
                .then((_) => refreshStatus()),
            icon: const Icon(Icons.account_circle_outlined)),
      ]),
      body: _HomeTabs(
        index: tab,
        home: RefreshIndicator(
          onRefresh: () async {
            refreshStatus();
            await Future.wait([
              ref.read(progressProvider.future),
              ref.read(assessmentHistoryProvider.future),
              ref.read(recentActivitiesProvider.future),
            ]);
          },
          child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              children: [
                _ProgressCard(
                    value: progress.valueOrNull ?? 0,
                    title: t.call('progress'),
                    subtitle: t.call('tagline'),
                    loading: progress.isLoading && !progress.hasValue),
                const SizedBox(height: 26),
                _SectionTitle(t.call('proficiency')),
                const SizedBox(height: 12),
                if (history.isLoading && !history.hasValue)
                  const LinearProgressIndicator()
                else if (latest.isEmpty)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(children: [
                            const _IconBadge(
                                icon: Icons.insights_rounded,
                                color: Brand.navy),
                            const SizedBox(width: 14),
                            Expanded(
                                child: Text(t.call('no_history'),
                                    style:
                                        const TextStyle(color: Brand.muted))),
                          ])))
                else
                  IntrinsicHeight(
                      child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final entry in latest.values.indexed) ...[
                        if (entry.$1 > 0) const SizedBox(width: 12),
                        Expanded(child: _ProficiencyCard(entry.$2)),
                      ],
                    ],
                  )),
                const SizedBox(height: 26),
                _SectionTitle(t.call('start')),
                const SizedBox(height: 12),
                _ActionCard(
                    icon: Icons.menu_book_rounded,
                    color: Brand.navy,
                    title: t.call('explore'),
                    subtitle: t.call('explore_sub'),
                    onTap: () => setState(() => tab = 1)),
                const SizedBox(height: 10),
                _ActionCard(
                    icon: Icons.quiz_rounded,
                    color: Brand.orange,
                    title: t.call('assess'),
                    subtitle: t.call('assess_sub'),
                    onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AssessmentScreen()))
                        .then((_) => refreshStatus())),
                const SizedBox(height: 10),
                _ActionCard(
                    icon: Icons.lightbulb_rounded,
                    color: Brand.blue,
                    title: t.call('recommend'),
                    subtitle: t.call('recommend_sub'),
                    onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const CatalogScreen(recommended: true)))
                        .then((_) => refreshStatus())),
                if ((activities.valueOrNull ?? [])
                    .any((a) => a['resource_title'] != null)) ...[
                  const SizedBox(height: 28),
                  Text(t.call('recent'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Brand.muted)),
                  const SizedBox(height: 10),
                  for (final activity in (activities.valueOrNull ?? [])
                      .where((a) => a['resource_title'] != null)
                      .take(3))
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(children: [
                          Expanded(
                              child: Text(activity['resource_title'].toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13, color: Brand.muted))),
                          const SizedBox(width: 12),
                          Text(_date(context, activity['created_at']),
                              style: const TextStyle(
                                  fontSize: 12, color: Brand.muted)),
                        ])),
                ],
              ]),
        ),
      ),
      bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (v) {
            if (v != tab) setState(() => tab = v);
          },
          destinations: [
            NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: t.call('home')),
            NavigationDestination(
                icon: const Icon(Icons.library_books_outlined),
                selectedIcon: const Icon(Icons.library_books_rounded),
                label: t.call('library')),
          ]),
    );
  }
}

String _date(BuildContext context, Object? value) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  return date == null
      ? ''
      : MaterialLocalizations.of(context).formatMediumDate(date.toLocal());
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Text(title,
      style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Brand.ink,
          letterSpacing: -0.4));
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard(
      {required this.value,
      required this.title,
      required this.subtitle,
      required this.loading});
  final double value;
  final String title, subtitle;
  final bool loading;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.clamp(0, 100).toDouble()),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, displayed, child) => Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Brand.navy, Color(0xFF087CC7)]),
                boxShadow: [
                  BoxShadow(
                      color: Brand.navy.withValues(alpha: .16),
                      blurRadius: 22,
                      offset: const Offset(0, 9))
                ]),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Stack(children: [
                  Positioned(
                      right: -34,
                      top: -48,
                      child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: .07)))),
                  Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.auto_graph_rounded,
                                  color: Brand.yellow, size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(title,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16))),
                            ]),
                            const SizedBox(height: 20),
                            Text(loading ? '—' : '${displayed.round()}%',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 46,
                                    height: 1,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.8)),
                            const SizedBox(height: 10),
                            Text(subtitle,
                                style: const TextStyle(
                                    color: Color(0xFFDEEEFF), fontSize: 14)),
                            const SizedBox(height: 20),
                            LinearProgressIndicator(
                                value: loading ? null : displayed / 100,
                                minHeight: 9,
                                borderRadius: BorderRadius.circular(20),
                                color: Brand.yellow,
                                backgroundColor:
                                    Colors.white.withValues(alpha: .22)),
                          ])),
                ])),
          ));
}

class _ProficiencyCard extends StatelessWidget {
  const _ProficiencyCard(this.result);
  final Map<String, Object?> result;
  @override
  Widget build(BuildContext context) {
    final math = result['subject'] == 'Mathematics';
    final color = math ? Brand.navy : Brand.orange;
    return Card(
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _IconBadge(
                      icon: math
                          ? Icons.calculate_rounded
                          : Icons.translate_rounded,
                      color: color),
                  const SizedBox(height: 14),
                  Text(result['subject'].toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Brand.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Text(result['level'].toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Brand.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('${result['score']}%',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: math ? Brand.navy : const Color(0xFFAA4B00),
                          fontSize: 25,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(_date(context, result['created_at']),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Brand.muted, fontSize: 12)),
                ])));
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(15)),
      child: Icon(icon,
          color: color == Brand.orange ? const Color(0xFFBF5700) : color,
          size: 25));
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                _IconBadge(icon: icon, color: color),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Brand.ink)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: const TextStyle(
                              color: Brand.muted, fontSize: 12, height: 1.4)),
                    ])),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded,
                    size: 20, color: Brand.navy),
              ]))));
}

// Keep both tabs mounted after their first visit so scroll positions, filters,
// and in-flight loads survive navigation without restarting animations.
class _HomeTabs extends StatefulWidget {
  const _HomeTabs({required this.index, required this.home});
  final int index;
  final Widget home;
  @override
  State<_HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<_HomeTabs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 240), value: 1);
  late final Animation<double> _opacity = Tween<double>(begin: .85, end: 1)
      .animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  bool _libraryVisited = false;

  @override
  void didUpdateWidget(covariant _HomeTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index == 1) _libraryVisited = true;
    if (oldWidget.index != widget.index) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
      opacity: _opacity,
      child: IndexedStack(index: widget.index, children: [
        TickerMode(
            enabled: widget.index == 0,
            child: RepaintBoundary(child: widget.home)),
        TickerMode(
            enabled: widget.index == 1,
            child: RepaintBoundary(
                child: _libraryVisited
                    ? const CatalogScreen()
                    : const SizedBox.shrink())),
      ]));
}
