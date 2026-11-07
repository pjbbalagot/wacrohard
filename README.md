# TULAI — Flutter + Supabase

Offline-first, guest-first learning app built with Flutter/Dart, Riverpod, SQLite, Supabase and an optional OpenAI-powered discovery Edge Function.

## MVP included

- Guest mode starts immediately; catalogue, packaged lessons, assessments and reading progress do not require an account or network.
- Three original starter lessons are bundled in SQLite: foundational Mathematics, everyday English vocabulary and digital literacy. These are TULAI-authored starter materials, **not** TESDA/DepEd publications.
- Local catalogue search and subject/language filters; published Supabase catalogue metadata is refreshed online and cached locally.
- Only resource files explicitly marked `redistribution_allowed=true` are downloaded for offline reading. Other materials open the original publisher's URL. Only verified translations are cached; machine translations are never presented as verified.
- Markdown reader with text-size and sepia appearance controls, saved reading position and local activity history.
- Six-question Mathematics and English Vocabulary assessments. Results are retained locally and previous attempts are preserved. Configurable MVP scoring bands: 0–39 Beginner, 40–59 Developing, 60–79 Intermediate, 80–100 Proficient. These are estimates, not formal qualifications.
- Deterministic local recommendations based on the latest subject result, proficiency and selected content language.
- English, Filipino and Ilocano core interface labels. Interface language and learning-content language are separate, persisted preferences. Content is not automatically translated.
- Optional Supabase email/password accounts. Guest records remain local until the learner reviews and explicitly approves migration.
- Consent-bound, idempotent sync for assessment results, reading positions and learning activity records. Signed-in learners can restore their own cloud history to a separate local cache on another device. Failed operations remain queued locally and retry when connectivity returns for the same approved account. Local copies are retained and account-owned rows are separated on shared devices.
- Authenticated catalogue-first OpenAI discovery through a Supabase Edge Function. It recommends exact published catalogue records first; any generated draft is labeled AI-generated and unverified and requires explicit confirmation before local saving.

## Requirements

- Flutter stable with Dart `>=3.3.0 <4.0.0`.
- Android Studio/Android SDK for Android; Xcode on macOS for iOS.
- A Supabase project for cloud catalogue, accounts, sync and AI discovery.
- Supabase CLI only if deploying with CLI; SQL Editor deployment is also supported.

## 1. Create platform folders and install dependencies

From this directory:

```bash
flutter create . --platforms=android,ios
flutter pub get
flutter analyze
flutter test
```

Run offline without Supabase configuration:

```bash
flutter run
```

## 2. Configure Supabase database

For a new Supabase project, open **SQL Editor → New query**, paste the complete contents of `supabase/migrations/001_initial_schema.sql`, and run it once. The script creates the schema, indexes, enums, profile trigger, RLS policies, grants, idempotency constraints and private Storage bucket.

If you already executed the earlier TULAI schema delivered before this completion update, run `supabase/migrations/002_completion_upgrade.sql` instead to upgrade reading-progress keys and tighten Storage download permissions. Do not run 002 after the revised 001 script.

Alternatively, with the Supabase CLI:

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

Do not run the initial SQL script repeatedly: it is a first-install migration, not a reset script.

### Dashboard configuration

1. **Authentication → Providers → Email**: enable Email/password. Configure email confirmation and the app's redirect/deep-link URLs for the release platforms.
2. **Storage**: the SQL creates a private `learning-materials` bucket. Its read policy permits only published resources with `redistribution_allowed=true`. Do not manually make this bucket public.
3. **Edge Functions → Secrets**: add `OPENAI_API_KEY`; optionally add `OPENAI_MODEL` (defaults to `gpt-4o-mini`). Never put the OpenAI key or service-role key in Flutter, `.env`, or a mobile build.
4. Publish catalogue resources only after checking the exact source, license, redistribution rights, and attribution. For material that cannot be redistributed, set `redistribution_allowed=false` and provide its official URL.
5. Add translations only with the correct source language, target language, translation method and review status. Machine translations must not be marked verified without actual human review.

## 3. Deploy OpenAI discovery

The Edge Function requires a valid signed-in Supabase user. It reads the published catalogue first and returns only exact resource IDs selected from that catalogue. The function does not save generated content. The app asks for confirmation before saving an AI-generated draft locally.

```bash
supabase functions deploy ai-resource-discovery
```

`supabase/config.toml` enables JWT verification. Supabase supplies `SUPABASE_URL` and `SUPABASE_ANON_KEY` to the function runtime; set only `OPENAI_API_KEY` and optionally `OPENAI_MODEL` as secrets.

## 4. Run with cloud features

Copy `.env.example` as a reference and pass the values as compile-time defines (Flutter does not automatically load `.env`):

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
```

The Supabase anon/publishable key is intended for client use; RLS is mandatory. Never use a service-role key in the client.

## Data and privacy behavior

- Guest assessment, preference, reading-position and activity data are stored in SQLite.
- No guest data is uploaded automatically. The account screen displays the number and type of eligible records before asking for approval. Guest records created while signed out remain local even if the device previously had sync consent; the learner must approve their association separately.
- Approval is associated with the currently signed-in user. Local copies remain after successful migration. Failed records remain local and are retried only for the approved account. Account-owned local rows and per-account cloud caches are separated so signing into another account does not show the previous account's cloud history.
- Reading progress for local-only starter resources is synchronized using a local resource key; it does not require inventing a Supabase resource UUID.
- Sign-out does not delete local records. If a different account is used, local records are not silently reassigned.
- On sign-in, the app downloads only that account's cloud assessments, progress and activity history into a separate local cache. RLS restricts assessment, progress, activity, library, profile and achievement records to their owner. Published catalogue metadata is readable by guests.

## Validation checklist

Run locally after installing Flutter:

```bash
flutter analyze
flutter test
flutter run
```

Manual checks:

1. Launch in airplane mode and confirm the three packaged lessons open and assessments save.
2. Change interface and content languages separately; restart and confirm both preferences persist.
3. Read a lesson, close it, reopen it and confirm the last reading position restores.
4. Complete and retake both assessments; confirm earlier attempts remain in history and proficiency boundaries match the tests.
5. Sign in, decline migration and confirm no cloud records are created. Repeat and approve; confirm only the signed-in owner's records are uploaded.
6. Interrupt network during migration; confirm local records remain and retry succeeds when online.
7. Publish a redistributable Markdown resource and a non-redistributable official-source link; confirm only the permitted file is cached.
8. Confirm an authenticated user can call AI discovery, a guest cannot, and the OpenAI key is absent from the mobile app.
9. Verify with two test accounts that neither can read or mutate the other's cloud records.

## Scope and known limitations

- The bundled lesson set is deliberately small and original. No TESDA/DepEd resource is claimed as packaged or endorsed. Add verified materials through the catalogue only after checking redistribution terms.
- The initial reader supports Markdown. PDF file viewing/download management, background OS scheduling, push notifications, formal institutional roles, contributor review UI, achievements UI and full LMS functions are outside this MVP.
- TULAI's core learner labels support English, Filipino and Ilocano. Some explanatory and AI discovery copy remains English; Ilocano's built-in Flutter Material chrome falls back to English. Native Ilocano/Filipino review is required before public release.
- AI output is not verified educational content, not an official recommendation, and not a source/license record. It remains clearly labeled and is never uploaded automatically.
- Flutter/Dart and Supabase CLI were not available in the authoring environment. Source, SQL and Edge Function were not compiled, device-tested or executed against a live Supabase project here. Run the validation steps above before release.
