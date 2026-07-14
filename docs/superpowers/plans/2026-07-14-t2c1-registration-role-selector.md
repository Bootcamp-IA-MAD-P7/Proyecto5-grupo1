# T2c.1 Registration Role Selector Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow public Flutter registration to explicitly choose `CAREGIVER` or `MONITORED` and send that exact role to the existing auth API.

**Architecture:** Keep role selection inside `LoginScreen`, reuse the existing `UserRole` enum and inject `AuthService` for widget-level contract tests. Add one localized prompt; `IT_ADMIN` remains absent from public UI.

**Tech Stack:** Flutter 3, Dart 3, `flutter_test`, `package:http/testing`, ARB localization.

## Global Constraints

- Public registration exposes only `CAREGIVER` and `MONITORED`.
- Default selection is `CAREGIVER`.
- The backend contract remains `POST /api/v1/auth/register`.
- No password or session persistence changes belong to T2c.1.

---

### Task 1: Render the public role selector

**Files:**
- Create: `frontend/test/login_screen_test.dart`
- Modify: `frontend/lib/screens/login_screen.dart`
- Modify: `frontend/lib/l10n/app_es.arb`
- Modify: `frontend/lib/l10n/app_en.arb`
- Regenerate: `frontend/lib/l10n/generated/app_localizations*.dart`

**Interfaces:**
- Consumes: `UserRole.caregiver`, `UserRole.monitored`, `context.l10n.roleCaregiver`, `context.l10n.roleMonitored`
- Produces: `LoginScreen(authService: AuthService?)` and selected `UserRole`

- [x] **Step 1: Write the failing widget test**

```dart
testWidgets('registro permite elegir CAREGIVER o MONITORED pero no IT_ADMIN',
    (tester) async {
  await tester.pumpWidget(buildLogin());
  await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
  await tester.pump();

  expect(find.text('Cuidador'), findsOneWidget);
  expect(find.text('Persona monitorizada'), findsOneWidget);
  expect(find.text('Administrador IT'), findsNothing);
});
```

- [x] **Step 2: Run the test and verify RED**

Run: `cd frontend && flutter test test/login_screen_test.dart`

Expected: FAIL because `Persona monitorizada` is not rendered.

- [x] **Step 3: Add localized selector UI**

Add `registrationRolePrompt` to both ARB files. In `LoginScreen`, add:

```dart
UserRole _selectedRole = UserRole.caregiver;

SegmentedButton<UserRole>(
  segments: [
    ButtonSegment(
      value: UserRole.caregiver,
      label: Text(context.l10n.roleCaregiver),
    ),
    ButtonSegment(
      value: UserRole.monitored,
      label: Text(context.l10n.roleMonitored),
    ),
  ],
  selected: {_selectedRole},
  onSelectionChanged: (roles) =>
      setState(() => _selectedRole = roles.single),
)
```

Keep the request temporarily unchanged so this step proves only rendering.

- [x] **Step 4: Regenerate localization and verify GREEN**

Run: `cd frontend && flutter gen-l10n && flutter test test/login_screen_test.dart`

Expected: PASS.

### Task 2: Send the selected role

**Files:**
- Modify: `frontend/test/login_screen_test.dart`
- Modify: `frontend/lib/screens/login_screen.dart`

**Interfaces:**
- Consumes: `AuthService.register({required UserRole role, ...})`
- Produces: request JSON with `"role": "CAREGIVER"` or `"role": "MONITORED"`

- [x] **Step 1: Add the failing HTTP contract widget test**

Inject `AuthService(client: MockClient(...))`, select `Persona monitorizada`, submit the form, decode the `/register` body and assert:

```dart
expect(jsonDecode(request.body)['role'], 'MONITORED');
```

- [x] **Step 2: Run the test and verify RED**

Run: `cd frontend && flutter test test/login_screen_test.dart`

Expected: FAIL because the request currently sends `CAREGIVER`.

- [x] **Step 3: Wire selection into registration**

Change the registration call to:

```dart
role: _selectedRole,
```

Initialize the state service from `widget.authService ?? AuthService()` so the test exercises the real request serializer.

- [x] **Step 4: Verify focused and full suites**

Run:

```bash
cd frontend
flutter test test/login_screen_test.dart
flutter test
flutter analyze
```

Expected: all tests pass and analyzer reports no issues.

### Task 3: Update executable backlog

**Files:**
- Modify: `.specify/specs/factoria/4_task.md`

**Interfaces:**
- Produces: T2c.1 marked complete with test evidence; T2c.2 explicitly names the fresh-DB seed migration.

- [x] **Step 1: Record evidence**

Mark `T2c.1` complete only after the focused test, full Flutter suite and analyzer pass.

- [x] **Step 2: Clarify T2c.2 seed requirement**

Specify a new Flyway migration after `V5__seed_demo_users.sql` that creates the default `monitored_persons` row by selecting `caregiver@sentilife.com` and `monitored@sentilife.com` from `users`, then enforces `user_id NOT NULL UNIQUE`. The implementation will run against a recreated PostgreSQL volume.
