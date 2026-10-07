import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../localization/app_localizations_x.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_date.dart';
import '../../core/widgets/ui_kit.dart';
import '../../models/employee.dart';
import '../../models/leave.dart';
import '../../models/permanence_record.dart';
import '../../models/status_type.dart';
import '../../repositories/reference_repository.dart';
import 'employee_form_screen.dart';

/// بطاقة الموظف: معلومات + سجل الوضعيات + الرخص + المداومة.
class EmployeeProfileScreen extends ConsumerStatefulWidget {
  const EmployeeProfileScreen({super.key, required this.employeeId});

  final int employeeId;

  @override
  ConsumerState<EmployeeProfileScreen> createState() =>
      _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends ConsumerState<EmployeeProfileScreen> {
  Employee? _employee;
  List<StatusHistoryEntry> _history = const <StatusHistoryEntry>[];
  List<Leave> _leaves = const <Leave>[];
  List<PermanenceRecord> _permanence = const <PermanenceRecord>[];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Employee? emp =
          await ref.read(employeeRepositoryProvider).findById(widget.employeeId);
      if (emp == null) {
        setState(() => _error = Exception('employee'));
        return;
      }
      final List<Object> rest = await Future.wait<Object>(<Future<Object>>[
        ref.read(statusRepositoryProvider).history(widget.employeeId),
        ref.read(leaveRepositoryProvider).forEmployee(
              widget.employeeId,
              includeCancelled: true,
            ),
        ref.read(permanenceRepositoryProvider).forEmployee(widget.employeeId),
      ]);
      if (!mounted) return;
      setState(() {
        _employee = emp;
        _history = rest[0] as List<StatusHistoryEntry>;
        _leaves = rest[1] as List<Leave>;
        _permanence = rest[2] as List<PermanenceRecord>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _edit() async {
    final Employee? emp = _employee;
    if (emp == null) return;
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EmployeeFormScreen(employee: emp),
      ),
    );
    if (saved == true) {
      ref.read(dbRevisionProvider.notifier).bump();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String lang = Localizations.localeOf(context).languageCode;
    final Employee? emp = _employee;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            emp == null
                ? l10n.employeeProfile
                : (lang == 'fr' ? emp.displayName : emp.displayNameAr),
          ),
          actions: <Widget>[
            if (emp != null)
              IconButton(
                tooltip: l10n.editEmployee,
                icon: const Icon(Icons.edit_outlined),
                onPressed: _edit,
              ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: l10n.tabInfo),
              Tab(text: l10n.tabStatus),
              Tab(text: l10n.tabLeaves),
              Tab(text: l10n.tabPermanence),
            ],
          ),
        ),
        body: _loading
            ? const LoadingView()
            : _error != null || emp == null
                ? ErrorView(error: _error ?? Exception(''), onRetry: _load)
                : TabBarView(
                    children: <Widget>[
                      _InfoTab(employee: emp),
                      _StatusTab(
                        entries: _history,
                        onAdd: () => _openAddStatus(),
                      ),
                      _LeavesTab(
                        leaves: _leaves,
                        onCancel: (Leave l) => _cancelLeave(l),
                      ),
                      _PermanenceTab(records: _permanence),
                    ],
                  ),
      ),
    );
  }

  // ── إضافة وضعية ──────────────────────────────────────────────

  Future<void> _openAddStatus() async {
    final AppLocalizations l10n = context.l10n;
    final ReferenceRepository refs = ref.read(referenceRepositoryProvider);
    final List<StatusType> types = await refs.statusTypes(activeOnly: true);
    if (!mounted) return;

    StatusType? selected = types.isEmpty ? null : types.first;
    DateTime start = AppDate.today();
    DateTime? end;
    final TextEditingController notes = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, void Function(void Function()) setSheet) {
          Future<void> pick(bool isEnd) async {
            final DateTime? d = await showDatePicker(
              context: ctx,
              initialDate: isEnd ? (end ?? start) : start,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (d == null) return;
            setSheet(() {
              if (isEnd) {
                end = d;
              } else {
                start = d;
                if (end != null && end!.isBefore(d)) end = null;
              }
            });
          }

          return Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.lg,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(l10n.addStatus, style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                if (types.isEmpty)
                  Text(l10n.noResults)
                else
                  DropdownButtonFormField<StatusType>(
                    initialValue: selected,
                    decoration: InputDecoration(labelText: l10n.statusType),
                    items: <DropdownMenuItem<StatusType>>[
                      for (final StatusType t in types)
                        DropdownMenuItem<StatusType>(value: t, child: Text(t.name)),
                    ],
                    onChanged: (StatusType? v) => setSheet(() => selected = v),
                  ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => pick(false),
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text(AppDate.format(start)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => pick(true),
                        icon: const Icon(Icons.event_outlined),
                        label: Text(end == null ? l10n.to : AppDate.format(end!)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: notes,
                  decoration: InputDecoration(labelText: l10n.notes),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () async {
                    if (selected == null) return;
                    if (end != null && end!.isBefore(start)) {
                      showAppSnack(ctx, l10n.errEndBeforeStart, isError: true);
                      return;
                    }
                    try {
                      await ref.read(statusRepositoryProvider).add(
                            employeeId: widget.employeeId,
                            statusTypeId: selected!.id!,
                            startDate: AppDate.format(start),
                            endDate: end == null ? null : AppDate.format(end!),
                            notes: notes.text.trim().isEmpty
                                ? null
                                : notes.text.trim(),
                          );
                      ref.read(dbRevisionProvider.notifier).bump();
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      _load();
                    } catch (e) {
                      if (ctx.mounted) {
                        showAppSnack(ctx, errorText(e, l10n), isError: true);
                      }
                    }
                  },
                  child: Text(l10n.save),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── إلغاء رخصة ───────────────────────────────────────────────

  Future<void> _cancelLeave(Leave leave) async {
    final AppLocalizations l10n = context.l10n;
    if (leave.id == null) return;
    final bool ok = await confirmAction(
      context,
      title: l10n.cancelLeave,
      message: l10n.leaveTypes,
      confirmLabel: l10n.confirm,
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(leaveRepositoryProvider).cancel(leave.id!);
      ref.read(dbRevisionProvider.notifier).bump();
      if (!mounted) return;
      showAppSnack(context, l10n.leaveCancelled);
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, errorText(e, l10n), isError: true);
    }
  }
}

// ── التبويبات ──────────────────────────────────────────────────

class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String lang = Localizations.localeOf(context).languageCode;

    return ListView(
      padding: AppSpacing.page,
      children: <Widget>[
        SectionCard(
          title: l10n.employeeCard,
          children: <Widget>[
            InfoRow(label: l10n.matricule, value: employee.matricule),
            InfoRow(
              label: l10n.fullNameAr,
              value: employee.nameAr.isEmpty ? null : employee.nameAr,
            ),
            InfoRow(
              label: l10n.fullNameFr,
              value: employee.nameFr.isEmpty ? null : employee.nameFr,
            ),
            InfoRow(label: l10n.section, value: employee.sectionName),
            InfoRow(label: l10n.grade, value: employee.gradeName),
            InfoRow(label: l10n.fonction, value: employee.functionName),
            InfoRow(label: l10n.quality, value: employee.quality),
            InfoRow(label: l10n.ppr, value: employee.ppr),
            InfoRow(label: l10n.mobilePhone, value: employee.mobilePhone),
            InfoRow(
              label: l10n.currentStatus,
              value: lang == 'fr'
                  ? (employee.statusNameFr ?? employee.displayStatus)
                  : employee.displayStatus,
            ),
            if ((employee.notes ?? '').trim().isNotEmpty)
              InfoRow(label: l10n.notes, value: employee.notes),
            InfoRow(
              label: l10n.status,
              value: employee.isActive ? l10n.active : l10n.inactive,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusTab extends StatelessWidget {
  const _StatusTab({required this.entries, required this.onAdd});

  final List<StatusHistoryEntry> entries;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final DateTime today = AppDate.today();

    final List<StatusHistoryEntry> current = entries.where((StatusHistoryEntry e) {
      if (e.endDate == null) return true;
      final DateTime? end = AppDate.tryParse(e.endDate);
      if (end == null) return false;
      return !end.isBefore(today);
    }).toList();
    final List<StatusHistoryEntry> previous =
        entries.where((StatusHistoryEntry e) => !current.contains(e)).toList();

    if (entries.isEmpty) {
      return EmptyState(
        icon: Icons.rule_outlined,
        title: l10n.noStatusHistory,
        hint: l10n.noStatusHistoryHint,
        action: FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: Text(l10n.addStatus),
        ),
      );
    }

    Widget tile(StatusHistoryEntry e) => Card(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: ListTile(
            title: Text(e.statusName ?? '${e.statusTypeId}'),
            subtitle: Text(
              '${AppDate.display(e.startDate)} → '
              '${e.endDate == null ? '…' : AppDate.display(e.endDate)}'
              '${(e.notes ?? '').isEmpty ? '' : ' • ${e.notes}'}',
            ),
            trailing: Icon(
              e.endDate == null ? Icons.radio_button_checked : Icons.history,
              size: 18,
              color: e.endDate == null ? AppColors.neon : AppColors.textTertiary,
            ),
          ),
        );

    return ListView(
      padding: AppSpacing.page,
      children: <Widget>[
        if (current.isNotEmpty) ...<Widget>[
          Text(l10n.currentRecord, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          for (final StatusHistoryEntry e in current) tile(e),
          const SizedBox(height: AppSpacing.md),
        ],
        if (previous.isNotEmpty) ...<Widget>[
          Text(l10n.previousRecords, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          for (final StatusHistoryEntry e in previous) tile(e),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: Text(l10n.addStatus),
        ),
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }
}

class _LeavesTab extends StatelessWidget {
  const _LeavesTab({required this.leaves, required this.onCancel});

  final List<Leave> leaves;
  final ValueChanged<Leave> onCancel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    if (leaves.isEmpty) {
      return EmptyState(
        icon: Icons.beach_access_outlined,
        title: l10n.noLeaves,
        hint: l10n.noLeavesHint,
      );
    }

    return ListView(
      padding: AppSpacing.page,
      children: <Widget>[
        for (final Leave l in leaves)
          Card(
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: ListTile(
              title: Text(
                l.leaveTypeName ?? '${l.leaveTypeId}',
                style: TextStyle(
                  decoration: l.isCancelled ? TextDecoration.lineThrough : null,
                  color: l.isCancelled ? AppColors.textTertiary : null,
                ),
              ),
              subtitle: Text(
                <String>[
                  '${AppDate.display(l.startDate)} → ${AppDate.display(l.endDate)}',
                  if (l.duration != null) l.displayDuration,
                  if (l.returnDate != null)
                    '${l10n.returnDate}: ${AppDate.display(l.returnDate)}',
                ].join('\n'),
              ),
              isThreeLine: true,
              trailing: l.isCancelled
                  ? null
                  : IconButton(
                      tooltip: l10n.cancelLeave,
                      icon: const Icon(Icons.cancel_outlined),
                      onPressed: () => onCancel(l),
                    ),
            ),
          ),
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }
}

class _PermanenceTab extends StatelessWidget {
  const _PermanenceTab({required this.records});

  final List<PermanenceRecord> records;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    if (records.isEmpty) {
      return EmptyState(
        icon: Icons.schedule_outlined,
        title: l10n.noPermanence,
        hint: l10n.noPermanenceArchive,
      );
    }

    return ListView(
      padding: AppSpacing.page,
      children: <Widget>[
        for (final PermanenceRecord r in records)
          Card(
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: ListTile(
              title: Text(
                <String>[
                  AppDate.display(r.date),
                  if ((r.timeSlot).isNotEmpty) r.timeSlot,
                ].join(' • '),
              ),
              subtitle: Text(
                <String>[
                  if ((r.scheduleText ?? '').isNotEmpty) r.scheduleText!,
                  if ((r.hpad ?? '').isNotEmpty) '${l10n.hpad}: ${r.hpad}',
                ].join('\n'),
              ),
              trailing: Text(
                r.derivedStatusName ?? '',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }
}
