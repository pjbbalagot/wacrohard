import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers.dart';
import '../../core/strings.dart';
import '../../data/local_store.dart';
import '../../data/sync_service.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false, busy = false;
  String message = '';
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) {
      setState(() => message =
          'Cloud accounts are not configured. Guest learning remains available.');
      return;
    }
    if (!email.text.contains('@') || password.text.length < 8) {
      setState(() => message =
          'Enter a valid email and a password with at least 8 characters.');
      return;
    }
    setState(() {
      busy = true;
      message = '';
    });
    try {
      final auth = client.auth;
      if (register) {
        final response = await auth.signUp(
            email: email.text.trim(), password: password.text);
        if (response.session == null) {
          message = 'Check your email to confirm your account, then sign in.';
        } else {
          message =
              'Account created. Your learning data remains local until you approve migration.';
        }
      } else {
        await auth.signInWithPassword(
            email: email.text.trim(), password: password.text);
        message =
            'Signed in. No guest records have been uploaded. Review migration below when ready.';
      }
      if (mounted) setState(() {});
    } on AuthException catch (e) {
      if (mounted) setState(() => message = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => message =
            'Unable to complete authentication. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> migrate() async {
    final client = ref.read(supabaseClientProvider);
    if (client == null || client.auth.currentUser == null) {
      setState(() => message = 'Sign in before reviewing migration.');
      return;
    }
    final sync = SyncService(LocalStore.instance, client);
    final counts =
        await sync.pendingCounts(userId: client.auth.currentUser!.id);
    if (!mounted) return;
    final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Review local learning data'),
              content: Text(
                  'The following records will be associated with your account and uploaded to your private learning history:\n\n${counts['assessments']} assessment results\n${counts['activities']} learning activity records\n${counts['progress']} reading-position records\n\nThis includes reading activity summaries and the last reading positions, not copies of the learning materials. Local copies remain on this device. Approving also enables retries when you are online. No records are uploaded unless you confirm.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep local only')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Approve migration'))
              ],
            ));
    if (approved != true) {
      setState(() => message =
          'Local records were kept on this device. Cloud sync remains disabled.');
      return;
    }
    setState(() => busy = true);
    try {
      await LocalStore.instance.setPreference('cloud_sync_consent', 'true');
      await LocalStore.instance
          .setPreference('cloud_sync_user_id', client.auth.currentUser!.id);
      await sync.migrateApprovedRecords(includeGuestRecords: true);
      if (mounted) {
        setState(() => message =
            'Migration completed. Future approved learning records will sync when online. Local copies remain on this device.');
      }
    } catch (_) {
      // Consent is stored before transmission so interrupted uploads can retry for this account.
      if (mounted) {
        setState(() => message =
            'Some records could not sync. Your local records and pending queue were preserved. Reconnect and retry from this screen if they do not sync automatically.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> confirmSignOut() async {
    final approved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Are you sure?'),
              content: const Text(
                  'Are you sure you want to sign out? Your local learning materials and progress will stay on this device.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFBA1A1A),
                        foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Sign out')),
              ],
            ));
    if (approved != true || !mounted) return;
    setState(() => busy = true);
    try {
      await ref.read(supabaseClientProvider)?.auth.signOut();
      if (mounted) {
        setState(() => message =
            'Signed out. Local learning data remains on this device.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => message = 'Could not sign out. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = T(ref.watch(languageProvider));
    final client = ref.watch(supabaseClientProvider);
    final user = client?.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text(t.call('account'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(t.call('account_info')),
          const SizedBox(height: 20),
          if (user != null) ...[
            ListTile(
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(user.email ?? 'Signed in',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              subtitle: const Text(
                'Your account is active. Guest records remain local until migration is approved.',
              ),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : migrate,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(t.call('migrate')),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFBA1A1A),
                  foregroundColor: Colors.white),
              onPressed: busy ? null : confirmSignOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            ),
          ] else ...[
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: t.call('email'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: password,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: t.call('password'),
                helperText: 'At least 8 characters',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : submit,
              child: Text(
                busy
                    ? 'Please wait…'
                    : register
                        ? t.call('signup')
                        : t.call('signin'),
              ),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                        register = !register;
                        message = '';
                      }),
              child: Text(
                register ? 'Already registered? Sign in' : 'Create an account',
              ),
            ),
          ],
          if (client == null)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Cloud accounts are not configured in this build. You can continue using all packaged lessons and assessments offline.',
              ),
            ),
          if (message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(message),
            ),
        ],
      ),
    );
  }
}
