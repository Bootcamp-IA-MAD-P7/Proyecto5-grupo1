import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/monitored_person.dart';
import '../services/auth_session.dart';
import '../services/monitored_service.dart';
import '../services/telemetry_service.dart';
import 'alerts_screen.dart';
import 'app_shell.dart';

/// SL-31 / T2.14 — Perfil CAREGIVER: lista de personas + estado.
class CaregiverHomeScreen extends StatefulWidget {
  final AuthSession session;
  final ValueChanged<Locale> onLocaleChanged;

  const CaregiverHomeScreen({
    super.key,
    required this.session,
    required this.onLocaleChanged,
  });

  @override
  State<CaregiverHomeScreen> createState() => _CaregiverHomeScreenState();
}

class _CaregiverHomeScreenState extends State<CaregiverHomeScreen> {
  final _monitored = MonitoredService();
  final _telemetry = TelemetryService();
  List<MonitoredPerson> _persons = [];
  bool _loading = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
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
      builder: (_) => const _AddPersonDialog(),
    );
    if (result == null) return;
    await _monitored.create(
      fullName: result.fullName,
      birthDate: result.birthDate,
      sex: result.sex,
      weightKg: result.weightKg,
      heightCm: result.heightCm,
      emergencyContact: result.emergencyContact,
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.caregiverTitle),
        actions: [
          AppTopActions(
            session: widget.session,
            onLocaleChanged: widget.onLocaleChanged,
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
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: _addPerson,
              child: const Icon(Icons.person_add),
            )
          : null,
    );
  }

  Widget _buildPersonsTab() {
    final l10n = context.l10n;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_persons.isEmpty) {
      return Center(child: Text(l10n.noPersonsYet));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _persons.length,
        itemBuilder: (context, i) => _PersonCard(
          person: _persons[i],
          telemetry: _telemetry,
        ),
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
    final statusColor = person.monitoringStatus == MonitoringStatus.active
        ? Colors.green
        : Colors.grey;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(Icons.person, color: statusColor),
        ),
        title: Text(person.fullName),
        subtitle: Text(
          '${l10n.age}: ${person.age} · ${l10n.consent}: ${person.consentStatus.value}\n'
          '${person.lastPrediction != null ? l10n.lastEvaluation : l10n.noEvaluationYet}',
        ),
        trailing: person.lastPrediction?.fallDetected == true
            ? const Icon(Icons.warning, color: Colors.red)
            : null,
        onTap: () async {
          final status = await telemetry.getStatus(person.id);
          if (!context.mounted) return;
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(person.fullName),
              content: Text(
                '${l10n.monitoringStatus}: ${status.monitoringStatus}\n'
                '${status.lastPrediction != null ? l10n.confidence((status.lastPrediction!.confidence * 100).toStringAsFixed(1)) : l10n.noEvaluationYet}',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.back)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PersonFormData {
  final String fullName;
  final String birthDate;
  final String sex;
  final double weightKg;
  final double heightCm;
  final String? emergencyContact;

  const _PersonFormData({
    required this.fullName,
    required this.birthDate,
    required this.sex,
    required this.weightKg,
    required this.heightCm,
    this.emergencyContact,
  });
}

class _AddPersonDialog extends StatefulWidget {
  const _AddPersonDialog();

  @override
  State<_AddPersonDialog> createState() => _AddPersonDialogState();
}

class _AddPersonDialogState extends State<_AddPersonDialog> {
  final _name = TextEditingController();
  final _birth = TextEditingController(text: '1950-01-01');
  final _weight = TextEditingController(text: '70');
  final _height = TextEditingController(text: '170');
  final _contact = TextEditingController();
  String _sex = 'M';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.addPerson),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, decoration: InputDecoration(labelText: l10n.fullName)),
            TextField(controller: _birth, decoration: InputDecoration(labelText: l10n.birthDate)),
            DropdownButtonFormField<String>(
              value: _sex,
              items: const [
                DropdownMenuItem(value: 'M', child: Text('M')),
                DropdownMenuItem(value: 'F', child: Text('F')),
              ],
              onChanged: (v) => setState(() => _sex = v ?? 'M'),
              decoration: InputDecoration(labelText: l10n.sex),
            ),
            TextField(controller: _weight, decoration: InputDecoration(labelText: l10n.weightKg)),
            TextField(controller: _height, decoration: InputDecoration(labelText: l10n.heightCm)),
            TextField(controller: _contact, decoration: InputDecoration(labelText: l10n.emergencyContact)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.back)),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              _PersonFormData(
                fullName: _name.text,
                birthDate: _birth.text,
                sex: _sex,
                weightKg: double.tryParse(_weight.text) ?? 70,
                heightCm: double.tryParse(_height.text) ?? 170,
                emergencyContact: _contact.text.isEmpty ? null : _contact.text,
              ),
            );
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
