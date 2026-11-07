import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/proficiency.dart';
import '../../core/strings.dart';
import '../../data/local_store.dart';
import '../../data/sync_service.dart';

class Q { const Q(this.prompt, this.options, this.answer); final String prompt; final List<String> options; final int answer; }
const math = [
  Q('What is 18 + 7?', ['24','25','26','27'], 1), Q('What is 40 - 16?', ['22','24','26','28'], 1),
  Q('What is 6 × 7?', ['36','40','42','48'], 2), Q('What is 56 ÷ 8?', ['6','7','8','9'], 1),
  Q('Which number is greatest?', ['0.8','0.75','0.65','0.7'], 0), Q('What is 125 + 75?', ['175','190','200','225'], 2),
];
const vocab = [
  Q('Which word means “to help”?', ['Assist','Avoid','Arrive','Announce'], 0), Q('Which word means “very important”?', ['Ordinary','Essential','Brief','Distant'], 1),
  Q('Choose a synonym for “rapid”.', ['Quiet','Slow','Quick','Late'], 2), Q('A “purchase” is something you…', ['borrow','buy','repair','lose'], 1),
  Q('Which word completes: “Please ___ the instructions.”', ['follow','borrow','arrive','occur'], 0), Q('“Generous” describes someone who…', ['shares willingly','is always late','speaks softly','runs quickly'], 0),
];
class AssessmentScreen extends ConsumerStatefulWidget {
  const AssessmentScreen({super.key});
  @override ConsumerState<AssessmentScreen> createState() => _AssessmentScreenState();
}
class _AssessmentScreenState extends ConsumerState<AssessmentScreen> {
  String? subject; int index = 0; final answers = <int>[]; bool done = false, saving = false;
  List<Q> get questions => subject == 'Mathematics' ? math : vocab;
  String level(int score) => proficiencyForScore(score);
  int get score => ((answers.asMap().entries.where((e) => e.value == questions[e.key].answer).length / questions.length) * 100).round();
  Future<void> finish() async {
    if (saving) return;
    setState(() => saving = true);
    try { final client = ref.read(supabaseClientProvider); final owner = await LocalStore.instance.approvedAccountId(client?.auth.currentUser?.id); await LocalStore.instance.saveAssessment(subject!, score, level(score), answers, ownerUserId: owner); if (client != null) await SyncService.syncIfConsented(LocalStore.instance, client); if (mounted) setState(() => done = true); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save this result locally: $e'))); }
    finally { if (mounted) setState(() => saving = false); }
  }
  @override Widget build(BuildContext context) {
    final t = T(ref.watch(languageProvider));
    return Scaffold(appBar: AppBar(title: Text(t.call('assessment'))), body: Padding(padding: const EdgeInsets.all(20), child:
      subject == null ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(t.call('choose'), style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 16),
        _pick('Mathematics'), _pick('English Vocabulary'), const Spacer(), Text(t.call('not_qualification')),
      ]) : done ? _result(t) : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        LinearProgressIndicator(value: (index + 1) / questions.length), const SizedBox(height: 24),
        Text('$subject • Question ${index + 1} of ${questions.length}'), const SizedBox(height: 18),
        Text(questions[index].prompt, style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 20),
        ...List.generate(questions[index].options.length, (i) => Padding(padding: const EdgeInsets.only(bottom: 8), child: OutlinedButton(
          onPressed: saving ? null : () { answers.add(i); if (index == questions.length - 1) { finish(); } else { setState(() => index++); } },
          child: Padding(padding: const EdgeInsets.all(12), child: Text(questions[index].options[i])),
        ))), const Spacer(), TextButton(onPressed: () => Navigator.pop(context), child: Text(t.call('skip'))),
      ])),
    );
  }
  Widget _pick(String value) => Card(child: ListTile(title: Text(value), subtitle: const Text('6 questions • approximately 3 minutes'), trailing: const Icon(Icons.arrow_forward), onTap: () => setState(() { subject = value; index = 0; answers.clear(); done = false; })));
  Widget _result(T t) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.check_circle_outline, size: 56), Text('$score%', style: Theme.of(context).textTheme.displayMedium),
    Text(t.call(level(score).toLowerCase()), style: Theme.of(context).textTheme.headlineMedium),
    Padding(padding: const EdgeInsets.all(20), child: Text(t.call('result_note'))),
    FilledButton(onPressed: () => Navigator.pop(context), child: Text(t.call('done'))),
    TextButton(onPressed: () => setState(() { index = 0; answers.clear(); done = false; }), child: Text(t.call('retake'))),
  ]));
}
