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
import '../../repositories/leave_repository.dart';
import '../../services/conflict_detector.dart';
import '../../services/leave_calculator.dart';

/// شاشة الرخص: قوائم (جارية/قادمة/منتهية) + إضافة مع معاينة حيّة.
class LeavesScreen extends ConsumerStatefulWidget {
  const LeavesScreen({super.key, this.addOnStart = false});

  final bool addOnStart;

  @override
  ConsumerState<LeavesScreen> createState() => _LeavesScreenState();
}

enum _LeaveTab { current, upcoming, ended }

class _LeavesScreenState extends ConsumerState<LeavesScreen> {
  _LeaveTab _tab = _LeaveTab.current;
  final TextEditingController _search = TextEditingController();

  List<Leave> _items = const <Leave>[];
  bool _loading = true;
  Object? _error;
  bool _openedAdd = false;

  /// رقم الطلب الجاري — النتائج الأقدم تُهمَش حتى لا تطغى على الأحدث.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  LeaveFilter get _filter {
    final String today = AppDate.format(AppDate.today());
    final String tomorrow = AppDate.format(AppDate.addDays(AppDate.today(), 1));
    final String yesterday =
        AppDate.format(AppDate.addDays(AppDate.today(), -1));
    switch (_tab) {
      case _LeaveTab.current:
        return LeaveFilter(from: today, to: today, text: _search.text);
      case _LeaveTab.upcoming:
        return LeaveFilter(from: tomorrow, text: _search.text);
      case _LeaveTab.ended:
        return LeaveFilter(to: yesterday, text: _search.text);
    }
  }

  Future<void> _load() async {
    final int request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final LeavePage page = await ref
          .read(leaveRepositoryProvider)
          .search(_filter, limit: 200);
      List<Leave> items = page.items;
      if (_tab == _LeaveTab.ended) {
        final String today = AppDate.format(AppDate.today());
        items = items
            .where((Leave l) =>
                AppDate.tryParse(l.endDate)
                        ?.isBefore(AppDate.tryParse(today)!) ??
                    true)
            .toList();
      }
      if (!mounted || request != _request) return;
      setState(() {
        _items = items;
        _loading = false;
      });
      if (widget.addOnStart && !_openedAdd) {
        _openedAdd = true;
        _openAdd();
      }
    } catch (e) {
      if (mounted && request == _request) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  // ── إضافة رخصة ───────────────────────────────────────────────

  Future<void> _openAdd() async {
    final AppLocalizations l10n = context.l10n;
    final LeaveRepository repo = ref.read(leaveRepositoryProvider);

    List<LeaveType> types = const <LeaveType>[];
    try {
      types = await repo.types(activeOnly: true);
    } catch (_) {}
    if (!mounted) return;

    LeaveType? type = types.isEmpty ? null : types.first;
    Employee? employee;
    DateTime start = AppDate.today();
    LeaveCalculationResult? calc;
    bool saving = false;

    Future<void> recompute() async {
      if (type == null) return;
      try {
        final LeaveCalculationResult r = await repo.preview(
          leaveTypeId: type!.id!,
          startDate: start,
        );
        calc = r;
      } catch (_) {
        calc = null;
      }
    }

    await recompute();

    Future<void> doSave({bool confirmed = false}) async {
      if (employee == null || type == null) return;
      await repo.create(
        employeeId: employee!.id!,
        leaveTypeId: type!.id!,
        startDate: AppDate.format(start),
        userConfirmed: confirmed,
      );
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, void Function(void Function()) setSheet) {
          List<Employee> suggestions = const <Employee>[];

          Future<void> searchEmployee(String q) async {
            if (q.trim().length < 2) {
              setSheet(() => suggestions = const <Employee>[]);
              return;
            }
            final List<Employee> found =
                await ref.read(employeeRepositoryProvider).suggest(q, limit: 6);
            if (ctx.mounted) setSheet(() => suggestions = found);
          }

          return Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.lg,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(l10n.addLeave,
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  if (types.isEmpty)
                    Text(l10n.noResults)
                  else
                    DropdownButtonFormField<LeaveType>(
                      initialValue: type,
                      decoration: InputDecoration(labelText: l10n.leaveType),
                      items: <DropdownMenuItem<LeaveType>>[
                        for (final LeaveType t in types)
                          DropdownMenuItem<LeaveType>(
                            value: t,
                            child: Text(
                              Localizations.localeOf(ctx).languageCode == 'fr'
                                  ? (t.nameFr ?? t.nameAr)
                                  : t.nameAr,
                            ),
                          ),
                      ],
                      onChanged: (LeaveType? v) async {
                        setSheet(() => type = v);
                        await recompute();
                        if (ctx.mounted) setSheet(() {});
                      },
                    ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final DateTime? d = await showDatePicker(
                        context: ctx,
                        initialDate: start,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d == null) return;
                      setSheet(() => start = d);
                      await recompute();
                      if (ctx.mounted) setSheet(() {});
                    },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text('${l10n.startDate}: ${AppDate.format(start)}'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    decoration: InputDecoration(
                      labelText: l10n.searchEmployee,
                      hintText: l10n.matricule,
                    ),
                    onChanged: searchEmployee,
                  ),
                  if (employee != null)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person),
                      title: Text(employee!.displayNameAr),
                      subtitle: Text(employee!.matricule),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setSheet(() => employee = null),
                      ),
                    ),
                  if (suggestions.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 150),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: suggestions.length,
                        itemBuilder: (BuildContext c, int i) {
                          final Employee e = suggestions[i];
                          return ListTile(
                            dense: true,
                            title: Text(e.displayNameAr),
                            subtitle: Text(e.matricule),
                            onTap: () => setSheet(() {
                              employee = e;
                              suggestions = const <Employee>[];
                            }),
                          );
                        },
                      ),
                    ),
                  if (calc != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: AppSpacing.tight,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: <Widget>[
                          InfoRow(
                            label: l10n.calculatedEnd,
                            value: AppDate.format(calc!.endDate),
                          ),
                          InfoRow(
                            label: l10n.calculatedReturn,
                            value: AppDate.format(calc!.returnDate),
                          ),
                          InfoRow(
                            label: l10n.duration,
                            value:
                                '${calc!.countedDuration} ${calc!.unit.name}',
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (employee == null || type == null) {
                              showAppSnack(
                                ctx,
                                l10n.errFieldRequired,
                                isError: true,
                              );
                              return;
                            }
                            setSheet(() => saving = true);
                            try {
                              await doSave();
                              ref.read(dbRevisionProvider.notifier).bump();
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              _load();
                            } on ConflictException catch (e) {
                              setSheet(() => saving = false);
                              if (!ctx.mounted) return;
                              final bool ok = await confirmAction(
                                ctx,
                                title: l10n.conflictDetected,
                                message: e.conflicts
                                    .map((DetectedConflict c) => c.message)
                                    .join('\n'),
                                confirmLabel: l10n.saveAnyway,
                                destructive: true,
                              );
                              if (!ok) return;
                              try {
                                await doSave(confirmed: true);
                                ref.read(dbRevisionProvider.notifier).bump();
                                if (ctx.mounted) Navigator.of(ctx).pop();
                                _load();
                              } catch (e2) {
                                if (ctx.mounted) {
                                  showAppSnack(
                                    ctx,
                                    errorText(e2, l10n),
                                    isError: true,
                                  );
                                }
                              }
                            } catch (e) {
                              setSheet(() => saving = false);
                              if (ctx.mounted) {
                                showAppSnack(
                                  ctx,
                                  errorText(e, l10n),
                                  isError: true,
                                );
                              }
                            }
                          },
                    child: Text(l10n.save),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.leavesTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.addLeave,
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _openAdd,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addLeave,
        onPressed: _openAdd,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: AppSpacing.page,
            child: SegmentedButton<_LeaveTab>(
              segments: <ButtonSegment<_LeaveTab>>[
                ButtonSegment<_LeaveTab>(
                  value: _LeaveTab.current,
                  label: Text(l10n.leavesCurrent),
                ),
                ButtonSegment<_LeaveTab>(
                  value: _LeaveTab.upcoming,
                  label: Text(l10n.leavesUpcoming),
                ),
                ButtonSegment<_LeaveTab>(
                  value: _LeaveTab.ended,
                  label: Text(l10n.leavesEnded),
                ),
              ],
              selected: <_LeaveTab>{_tab},
              onSelectionChanged: (Set<_LeaveTab> s) {
                setState(() => _tab = s.first);
                _load();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (_) {
                setState(() {});
                _load();
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _error != null
                    ? ErrorView(error: _error!, onRetry: _load)
                    : _items.isEmpty
                        ? EmptyState(
                            icon: Icons.beach_access_outlined,
                            title: l10n.noLeaves,
                            hint: l10n.noLeavesHint,
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                0,
                                AppSpacing.lg,
                                96,
                              ),
                              itemCount: _items.length,
                              itemBuilder: (BuildContext context, int i) {
                                final Leave l = _items[i];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.xs,
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      l.leaveTypeName ?? '${l.leaveTypeId}',
                                    ),
                                    subtitle: Text(
                                      <String>[
                                        l.employeeName ?? '',
                                        '${AppDate.display(l.startDate)} → '
                                            '${AppDate.display(l.endDate)}',
                                        if (l.duration != null)
                                          l.displayDuration,
                                      ].where((String s) => s.isNotEmpty).join('\n'),
                                    ),
                                    isThreeLine: true,
                                    trailing: l.isCancelled
                                        ? Chip(
                                            label: Text(l10n.leaveCancelled),
                                          )
                                        : null,
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
