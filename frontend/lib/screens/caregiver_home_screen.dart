import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../l10n/l10n.dart';
import '../models/monitored_person.dart';
import '../models/user.dart';
import '../services/auth_session.dart';
import '../services/exceptions.dart';
import '../services/monitored_service.dart';
import '../services/telemetry_service.dart';
import '../widgets/assistant_fab.dart';
import '../widgets/gradient_app_bar.dart';
import 'alerts_screen.dart';
import 'app_shell.dart';

/// SL-31 / T2.14 — Perfil CAREGIVER: lista de personas + estado.
class CaregiverHomeScreen extends StatefulWidget {
  final AuthSession session;
  final ValueChanged<Locale> onLocaleChanged;
  final MonitoredService? monitoredService;

  const CaregiverHomeScreen({
    super.key,
    required this.session,
    required this.onLocaleChanged,
    this.monitoredService,
  });

  @override
  State<CaregiverHomeScreen> createState() => _CaregiverHomeScreenState();
}

class _CaregiverHomeScreenState extends State<CaregiverHomeScreen> {
  late final MonitoredService _monitored;
  final _telemetry = TelemetryService();
  List<MonitoredPerson> _persons = [];
  bool _loading = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _monitored = widget.monitoredService ?? MonitoredService();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final page = await _monitored.list();
    setState(() {
      _persons = page.content;
      _loading = false;
    });
  }

  Future<void> _addPerson() async {
    final result = await showDialog<_PersonFormData>(
      context: context,
      builder: (_) => _AddPersonDialog(monitoredService: _monitored),
    );
    if (result == null) return;
    try {
      await _monitored.create(
        monitoredUserEmail: result.monitoredUserEmail,
        fullName: result.fullName,
        birthDate: result.birthDate,
        sex: result.sex,
        weightKg: result.weightKg,
        heightCm: result.heightCm,
        emergencyContact: result.emergencyContact,
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final locale = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: GradientAppBar(
        title: 'SentiLife',
        actions: [
          AppTopActions(
            session: widget.session,
            onLocaleChanged: widget.onLocaleChanged,
            role: UserRole.caregiver,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.people), label: l10n.persons),
          NavigationDestination(icon: const Icon(Icons.notifications), label: l10n.alerts),
        ],
      ),
      body: _tab == 0 ? _buildPersonsTab() : AlertsScreen(embedded: true),
      floatingActionButton: AssistantFabColumn(
        locale: locale,
        primaryFab: _tab == 0
            ? FloatingActionButton(
                heroTag: 'caregiver-add-person',
                onPressed: _addPerson,
                child: const Icon(Icons.person_add),
              )
            : null,
      ),
    );
  }

  Widget _buildPersonsTab() {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;
    final user = widget.session.user!;
    final firstName = user.fullName.split(' ').first;

    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_persons.isEmpty) {
      return Center(child: Text(l10n.noPersonsYet));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _persons.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Text(
                locale == 'en'
                    ? 'Hi $firstName, here are your monitored people'
                    : 'Hola $firstName, aquí están tus monitorizados',
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                ),
              ),
            );
          }
          return _PersonCard(
            person: _persons[i - 1],
            telemetry: _telemetry,
          );
        },
      ),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final MonitoredPerson person;
  final TelemetryService telemetry;

  const _PersonCard({required this.person, required this.telemetry});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isActive = person.monitoringStatus == MonitoringStatus.active;
    final statusColor = isActive ? AppTheme.success : AppTheme.textSecondary;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final status = await telemetry.getStatus(person.id);
          if (!context.mounted) return;
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(person.fullName),
              content: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${l10n.monitoringStatus}: ${status.monitoringStatus}\n'),
                    if (status.lastPrediction != null)
                      TextSpan(
                        text: l10n.confidence((status.lastPrediction!.confidence * 100).toStringAsFixed(1)),
                        style: AppTheme.monoStyle(fontSize: 14),
                      )
                    else
                      TextSpan(text: l10n.noEvaluationYet),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.back)),
              ],
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar with status indicator
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      person.fullName.isNotEmpty ? person.fullName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.age}: ${person.age} · ${l10n.consent}: ${person.consentStatus.value}',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    if (person.pairingCode != null) ...[
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: '${l10n.pairingCodeShare}: '),
                            TextSpan(
                              text: person.pairingCode,
                              style: AppTheme.monoStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Warning icon if fall detected
              if (person.lastPrediction?.fallDetected == true)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.warning_rounded, color: AppTheme.danger, size: 20),
                )
              else
                const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonFormData {
  final String monitoredUserEmail;
  final String fullName;
  final String birthDate;
  final String sex;
  final double weightKg;
  final double heightCm;
  final String? emergencyContact;

  const _PersonFormData({
    required this.monitoredUserEmail,
    required this.fullName,
    required this.birthDate,
    required this.sex,
    required this.weightKg,
    required this.heightCm,
    this.emergencyContact,
  });
}

class _AddPersonDialog extends StatefulWidget {
  const _AddPersonDialog({required this.monitoredService});

  final MonitoredService monitoredService;

  @override
  State<_AddPersonDialog> createState() => _AddPersonDialogState();
}

class _AddPersonDialogState extends State<_AddPersonDialog> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _weight = TextEditingController(text: '70');
  final _height = TextEditingController(text: '170');
  final _contact = TextEditingController();
  Timer? _emailLookupTimer;
  String _sex = 'M';
  String? _emailError;
  String? _birthDateError;
  DateTime? _birthDate;
  bool _lookupInFlight = false;
  bool _accountValidated = false;

  MonitoredService get _monitoredService => widget.monitoredService;

  @override
  void dispose() {
    _emailLookupTimer?.cancel();
    _email.dispose();
    _name.dispose();
    _weight.dispose();
    _height.dispose();
    _contact.dispose();
    super.dispose();
  }

  String _formatBirthDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void _scheduleEmailLookup() {
    _emailLookupTimer?.cancel();
    _emailLookupTimer = Timer(const Duration(milliseconds: 450), () {
      unawaited(_lookupEmailAccount());
    });
  }

  Future<void> _lookupEmailAccount() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() {
        _accountValidated = false;
        _name.clear();
        _emailError = null;
      });
      return;
    }

    setState(() {
      _lookupInFlight = true;
      _emailError = null;
      _accountValidated = false;
      _name.clear();
    });

    try {
      final account = await _monitoredService.lookupLinkableAccount(email);
      if (!mounted) return;
      if (account.alreadyLinked) {
        setState(() {
          _emailError = context.l10n.monitoredAccountAlreadyLinked;
          _lookupInFlight = false;
        });
        return;
      }
      if (!account.active) {
        setState(() {
          _emailError = context.l10n.monitoredAccountInactive;
          _lookupInFlight = false;
        });
        return;
      }
      setState(() {
        _name.text = account.fullName;
        _accountValidated = true;
        _lookupInFlight = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _emailError = e.status == 404
            ? context.l10n.monitoredAccountLookupError
            : e.message;
        _lookupInFlight = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _emailError = context.l10n.monitoredAccountLookupError;
        _lookupInFlight = false;
      });
    }
  }

  Future<void> _pickBirthDate(AppLocalizations l10n) async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 70, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now.subtract(const Duration(days: 1)),
      helpText: l10n.selectBirthDate,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _birthDate = picked;
      _birthDateError = null;
    });
  }

  void _submit(AppLocalizations l10n) {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = l10n.monitoredUserEmailRequired);
      return;
    }
    if (!_accountValidated || _name.text.trim().isEmpty) {
      setState(
        () => _emailError ??= l10n.monitoredAccountLookupError,
      );
      return;
    }
    if (_birthDate == null) {
      setState(() => _birthDateError = l10n.birthDateRequired);
      return;
    }

    Navigator.pop(
      context,
      _PersonFormData(
        monitoredUserEmail: email,
        fullName: _name.text.trim(),
        birthDate: _formatBirthDate(_birthDate!),
        sex: _sex,
        weightKg: double.tryParse(_weight.text) ?? 70,
        heightCm: double.tryParse(_height.text) ?? 170,
        emergencyContact: _contact.text.isEmpty ? null : _contact.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = (size.width * 0.92).clamp(320.0, 560.0);
    final dialogMaxHeight = size.height * 0.82;
    final birthLabel = _birthDate == null
        ? l10n.selectBirthDate
        : _formatBirthDate(_birthDate!);

    Widget fieldSpacing(Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: child,
        );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          minWidth: dialogWidth,
          maxHeight: dialogMaxHeight,
        ),
        child: Theme(
          data: theme.copyWith(
            inputDecorationTheme: theme.inputDecorationTheme.copyWith(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              isDense: true,
            ),
          ),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.addPerson,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: l10n.back,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    fieldSpacing(
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: l10n.monitoredUserEmail,
                          errorText: _emailError,
                          suffixIcon: _lookupInFlight
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : _accountValidated
                                  ? const Icon(Icons.check_circle, color: Colors.green)
                                  : null,
                        ),
                        onChanged: (_) {
                          setState(() {
                            _emailError = null;
                            _accountValidated = false;
                            _name.clear();
                          });
                          _scheduleEmailLookup();
                        },
                        onSubmitted: (_) => unawaited(_lookupEmailAccount()),
                      ),
                    ),
                    fieldSpacing(
                      TextField(
                        controller: _name,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: l10n.fullNameFromAccount,
                          hintText: l10n.monitoredAccountValidated,
                        ),
                      ),
                    ),
                    fieldSpacing(
                      InkWell(
                        onTap: () => unawaited(_pickBirthDate(l10n)),
                        borderRadius: BorderRadius.circular(10),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: l10n.birthDate,
                            errorText: _birthDateError,
                            suffixIcon: const Icon(Icons.calendar_today, size: 20),
                          ),
                          child: Text(birthLabel, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ),
                    fieldSpacing(
                      Row(
                        children: [
                          SizedBox(
                            width: 70,
                            child: DropdownButtonFormField<String>(
                              // ignore: deprecated_member_use
                              value: _sex,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: 'M', child: Text('M')),
                                DropdownMenuItem(value: 'F', child: Text('F')),
                              ],
                              onChanged: (v) => setState(() => _sex = v ?? 'M'),
                              decoration: InputDecoration(labelText: l10n.sex),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _weight,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(labelText: l10n.weightKg),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _height,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(labelText: l10n.heightCm),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextField(
                      controller: _contact,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(labelText: l10n.emergencyContact),
                      onSubmitted: (_) => _submit(l10n),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.back),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _lookupInFlight ? null : () => _submit(l10n),
                    child: Text(l10n.save),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
