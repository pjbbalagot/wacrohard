import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

bool canDeleteMaterial(Map<String, Object?> resource) =>
    resource['content_type'] == 'ai_generated' &&
    resource['remote_managed'] != 1;

Future<bool> deleteMaterial(
    BuildContext context, WidgetRef ref, Map<String, Object?> resource) async {
  if (!canDeleteMaterial(resource)) return false;
  final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
            title: const Text('Delete generated material?'),
            content: Text(
                'Delete “${resource['title']}” and its local reading progress from this device?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete')),
            ],
          ));
  if (confirmed != true || !context.mounted) return false;
  try {
    final deleted = await ref
        .read(storeProvider)
        .deleteGeneratedResource(resource['id'] as String);
    if (!deleted) throw StateError('Material cannot be deleted');
    ref.invalidate(catalogueProvider);
    ref.invalidate(progressProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generated material deleted.')));
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not delete material. Please try again.')));
    }
    return false;
  }
}
