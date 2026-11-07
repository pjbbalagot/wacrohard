import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/local_store.dart';
import '../reader/read_aloud.dart';

class AiDiscoveryScreen extends ConsumerStatefulWidget {
  const AiDiscoveryScreen({super.key});

  @override
  ConsumerState<AiDiscoveryScreen> createState() => _AiDiscoveryScreenState();
}

class _AiDiscoveryScreenState extends ConsumerState<AiDiscoveryScreen> {
  final TextEditingController request = TextEditingController();

  String subject = 'Mathematics';
  String proficiency = 'Beginner';
  String language = 'en';

  bool loading = false;
  bool saving = false;

  Map<String, dynamic>? result;
  String? error;

  @override
  void initState() {
    super.initState();
    final preferred = ref.read(contentLanguageProvider);
    language = preferred == 'all' ? 'en' : preferred;
  }

  @override
  void dispose() {
    request.dispose();
    super.dispose();
  }

  // ======================================
  // AI RESOURCE DISCOVERY
  // ======================================

  Future<void> discover() async {
    final client = ref.read(supabaseClientProvider);

    if (client == null) {
      setState(() {
        error = 'Cloud services are not configured.';
      });
      return;
    }

    if (client.auth.currentUser == null) {
      setState(() {
        error = 'Please sign in to use AI-assisted learning.';
      });
      return;
    }

    if (request.text.trim().length < 3) {
      setState(() {
        error = 'Please describe what you want to learn.';
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
      result = null;
    });

    try {
      final response = await client.functions.invoke(
        'ai-resource-discovery',
        body: {
          'request': request.text.trim(),
          'subject': subject,
          'proficiency': proficiency,
          'language': language,
        },
      );

      if (response.status < 200 || response.status >= 300) {
        throw Exception(
          'AI request failed (${response.status}).',
        );
      }

      if (response.data is! Map) {
        throw Exception('Invalid AI response format.');
      }

      final data = Map<String, dynamic>.from(
        response.data as Map,
      );

      if (data['error'] != null) {
        throw Exception(data['error'].toString());
      }

      if (!mounted) return;

      setState(() {
        result = data;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = 'AI discovery failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ======================================
  // CONVERT AI LESSON TO MARKDOWN
  // ======================================

  String draftMarkdown(Map<String, dynamic> draft) {
    final out = StringBuffer();

    out.writeln(
      '# ${draft['title'] ?? 'AI Learning Lesson'}\n',
    );

    // Introduction
    if (draft['introduction'] != null) {
      out.writeln('## Introduction\n');
      out.writeln('${draft['introduction']}\n');
    }

    // Learning objectives
    final objectives = draft['learning_objectives'];

    if (objectives is List && objectives.isNotEmpty) {
      out.writeln('## Learning Objectives\n');

      for (final objective in objectives) {
        out.writeln('- $objective');
      }

      out.writeln();
    }

    // Lesson sections
    final sections = draft['sections'];

    if (sections is List) {
      for (final section in sections) {
        if (section is! Map) continue;

        out.writeln(
          '## ${section['heading'] ?? 'Lesson Section'}\n',
        );

        out.writeln(
          '${section['content'] ?? ''}\n',
        );

        final examples = section['examples'];

        if (examples is List && examples.isNotEmpty) {
          out.writeln('### Examples\n');

          for (final example in examples) {
            out.writeln('- $example');
          }

          out.writeln();
        }
      }
    }

    // Practice questions
    final questions = draft['practice_questions'];

    if (questions is List && questions.isNotEmpty) {
      out.writeln('## Practice Questions\n');

      for (var i = 0; i < questions.length; i++) {
        final question = questions[i];

        if (question is! Map) continue;

        out.writeln(
          '### Question ${i + 1}\n',
        );

        out.writeln(
          '${question['question'] ?? ''}\n',
        );

        final options = question['options'];

        if (options is List) {
          for (final option in options) {
            out.writeln('- $option');
          }
        }

        out.writeln();

        out.writeln(
          '**Correct Answer:** '
          '${question['correct_answer'] ?? 'Not provided'}\n',
        );

        out.writeln(
          '**Explanation:** '
          '${question['explanation'] ?? ''}\n',
        );
      }
    }

    // Summary
    if (draft['summary'] != null) {
      out.writeln('## Summary\n');
      out.writeln('${draft['summary']}\n');
    }

    out.writeln('---');
    out.writeln(
      '> AI-generated and unverified. '
      'Review accuracy and references before relying '
      'on this material.',
    );

    return out.toString();
  }

  // ======================================
  // SAVE LESSON FOR OFFLINE READING
  // ======================================

  Future<void> saveDraft() async {
    final draft = result?['generated_draft'];

    if (draft is! Map) return;

    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save AI-generated lesson?'),
        content: const Text(
          'This lesson will be saved on your device '
          'for offline reading.\n\n'
          'AI-generated content may contain errors '
          'and has not been independently verified.\n\n'
          'Would you like to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            child: const Text('Save Lesson'),
          ),
        ],
      ),
    );

    if (approved != true) return;

    setState(() {
      saving = true;
    });

    try {
      final map = Map<String, dynamic>.from(draft);

      final title = (map['title'] ?? 'AI Learning Lesson').toString();

      final content = draftMarkdown(map);

      await LocalStore.instance.saveGeneratedResource(
        title: title,
        description: 'AI-generated and unverified learning material.',
        subject: subject,
        language: language,
        difficulty: proficiency,
        content: content,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lesson saved successfully. '
            'You can read it offline in your library.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save lesson: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  // ======================================
  // DISPLAY GENERATED LESSON
  // ======================================

  Widget buildGeneratedLesson(
    Map<String, dynamic> draft,
  ) {
    final theme = Theme.of(context);

    final objectives = draft['learning_objectives'];
    final sections = draft['sections'];
    final questions = draft['practice_questions'];

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lesson title
            Text(
              (draft['title'] ?? 'AI Learning Lesson').toString(),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            const Chip(
              avatar: Icon(
                Icons.auto_awesome,
                size: 18,
              ),
              label: Text(
                'AI-generated and unverified',
              ),
            ),

            const Divider(height: 32),

            // Introduction
            if (draft['introduction'] != null) ...[
              Text(
                'Introduction',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                draft['introduction'].toString(),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
            ],

            // Learning objectives
            if (objectives is List && objectives.isNotEmpty) ...[
              Text(
                'Learning Objectives',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final objective in objectives)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          objective.toString(),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
            ],

            // Lesson sections
            if (sections is List && sections.isNotEmpty) ...[
              Text(
                'Lesson Content',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              for (final section in sections)
                if (section is Map) ...[
                  Text(
                    (section['heading'] ?? 'Lesson Section').toString(),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  SelectableText(
                    (section['content'] ?? '').toString(),
                    style: theme.textTheme.bodyLarge,
                  ),

                  const SizedBox(height: 12),

                  // Examples
                  if (section['examples'] is List &&
                      (section['examples'] as List).isNotEmpty) ...[
                    Text(
                      'Examples',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    for (final example in section['examples'] as List)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '• ${example.toString()}',
                        ),
                      ),
                  ],

                  const Divider(height: 32),
                ],
            ],

            // Practice questions
            if (questions is List && questions.isNotEmpty) ...[
              Text(
                'Practice Questions',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < questions.length; i++)
                if (questions[i] is Map) ...[
                  Text(
                    'Question ${i + 1}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    (questions[i]['question'] ?? '').toString(),
                  ),

                  const SizedBox(height: 8),

                  if (questions[i]['options'] is List)
                    for (final option in questions[i]['options'] as List)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '• ${option.toString()}',
                        ),
                      ),

                  const SizedBox(height: 12),

                  // Answer and explanation
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text(
                      'Show Answer and Explanation',
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Correct Answer: '
                              '${questions[i]['correct_answer'] ?? 'Not provided'}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Explanation: '
                              '${questions[i]['explanation'] ?? 'No explanation available.'}',
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 24),
                ],
            ],

            // Summary
            if (draft['summary'] != null) ...[
              Text(
                'Lesson Summary',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              SelectableText(
                draft['summary'].toString(),
                style: theme.textTheme.bodyLarge,
              ),
            ],

            const SizedBox(height: 24),

            const Text(
              'Disclaimer: This material is '
              'AI-generated and unverified. '
              'Check its accuracy before relying on it.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================================
  // DISPLAY EXISTING RESOURCES
  // ======================================

  Widget buildExistingResources(List resources) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Existing Learning Resources',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        for (final item in resources)
          if (item is Map)
            Card(
              child: ListTile(
                leading: const Icon(Icons.menu_book),
                title: Text(
                  (item['title'] ?? 'Learning Resource').toString(),
                ),
                subtitle: Text(
                  '${item['description'] ?? ''}\n'
                  '${item['subject'] ?? ''} • '
                  '${item['difficulty'] ?? ''}\n'
                  'Source: ${item['author_organization'] ?? 'Not specified'}',
                ),
                isThreeLine: true,
              ),
            ),
      ],
    );
  }

  // ======================================
  // MAIN USER INTERFACE
  // ======================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Learning Discovery'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Discover Learning Resources',
            style: Theme.of(context).textTheme.headlineSmall,
          ),

          const SizedBox(height: 8),

          const Text(
            'Describe what you want to learn. '
            'TULAI will look for existing resources '
            'and generate learning content when needed.',
          ),

          const SizedBox(height: 24),

          // Learning request
          TextField(
            controller: request,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'What do you want to learn?',
              hintText: 'Example: Teach me basic fractions with examples.',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.edit_note),
            ),
          ),

          const SizedBox(height: 12),

          // Subject
          DropdownButtonFormField<String>(
            initialValue: subject,
            decoration: const InputDecoration(
              labelText: 'Subject',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'Mathematics',
                child: Text('Mathematics'),
              ),
              DropdownMenuItem(
                value: 'English',
                child: Text('English'),
              ),
            ],
            onChanged: loading
                ? null
                : (value) {
                    setState(() {
                      subject = value ?? subject;
                    });
                  },
          ),

          const SizedBox(height: 16),

          // Proficiency
          DropdownButtonFormField<String>(
            initialValue: proficiency,
            decoration: const InputDecoration(
              labelText: 'Proficiency Level',
              border: OutlineInputBorder(),
            ),
            items: [
              'Beginner',
              'Developing',
              'Intermediate',
              'Proficient',
            ]
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: loading
                ? null
                : (value) {
                    setState(() {
                      proficiency = value ?? proficiency;
                    });
                  },
          ),

          const SizedBox(height: 16),

          // Language
          DropdownButtonFormField<String>(
            initialValue: language,
            decoration: const InputDecoration(
              labelText: 'Content Language',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: 'en',
                child: Text('English'),
              ),
              DropdownMenuItem(
                value: 'fil',
                child: Text('Filipino'),
              ),
              DropdownMenuItem(
                value: 'ilo',
                child: Text('Ilocano'),
              ),
            ],
            onChanged: loading
                ? null
                : (value) {
                    setState(() {
                      language = value ?? language;
                    });
                  },
          ),

          const SizedBox(height: 24),

          // Generate button
          FilledButton.icon(
            onPressed: loading ? null : discover,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(
              loading
                  ? 'Generating Learning Content...'
                  : 'Generate Learning Content',
            ),
          ),

          // Error message
          if (error != null) ...[
            const SizedBox(height: 20),
            Text(
              error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],

          // AI response
          if (result != null) ...[
            const SizedBox(height: 28),

            Text(
              'Learning Results',
              style: Theme.of(context).textTheme.headlineSmall,
            ),

            const Divider(height: 24),

            // Existing resources
            if (result!['existing_resources'] is List &&
                (result!['existing_resources'] as List).isNotEmpty)
              buildExistingResources(
                result!['existing_resources'] as List,
              ),

            // Generated lesson
            if (result!['generated_draft'] is Map) ...[
              ReadAloud(
                content: draftMarkdown(Map<String, dynamic>.from(
                    result!['generated_draft'] as Map)),
                language: language,
              ),
              buildGeneratedLesson(
                Map<String, dynamic>.from(
                  result!['generated_draft'] as Map,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: saving ? null : saveDraft,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  saving
                      ? 'Saving Lesson...'
                      : 'Save Lesson for Offline Reading',
                ),
              ),
              TextButton.icon(
                onPressed: saving || loading
                    ? null
                    : () => setState(() {
                          result = Map<String, dynamic>.from(result!)
                            ..remove('generated_draft');
                        }),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Discard generated draft'),
              ),
            ],

            // No lesson content
            if (result!['generated_draft'] is! Map &&
                (result!['existing_resources'] is! List ||
                    (result!['existing_resources'] as List).isEmpty))
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No learning content was returned. '
                  'Please try another learning request.',
                ),
              ),

            const SizedBox(height: 30),
          ],
        ],
      ),
    );
  }
}
