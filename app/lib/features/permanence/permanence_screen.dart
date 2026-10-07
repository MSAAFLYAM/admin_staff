import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../localization/app_localizations_x.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_date.dart';
import '../../core/widgets/ui_kit.dart';
import '../../models/employee.dart';
import '../../models/permanence_record.dart';

/// شاشة المداومة: عرض اليوم (تنقّل يومي) + إضافة/ربط/حذف.
class PermanenceScreen extends ConsumerStatefulWidget {
  const PermanenceScreen({super.key, this.addOnStart = false});

  /// يفتح نافذة الإضافة فور دخول الشاشة (من لوحة القيادة).
  final bool addOnStart;

  @override
  ConsumerState<PermanenceScreen> createState() => _PermanenceScreenState();
}

class _PermanenceScreenState extends ConsumerState<PermanenceScreen> {
  DateTime _day = AppDate.today();
  List<PermanenceRecord> _records = const <PermanenceRecord>[];
  bool _loading = true;
  Object? _error;
  bool _openedAdd = false;

  /// رقم الطلب الجاري — نتائج الأيام السابقة تُهمَش بعد تنقّل سريع.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _dateKey => AppDate.format(_day);

  Future<void> _load() async {
    final int request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<PermanenceRecord> rows =
          await ref.read(permanenceRepositoryProvider).forDate(_dateKey);
      if (!mounted || request != _request) return;
      setState(() {
        _records = rows;
        _loading = false;
      });
      if (widget.addOnStart && !_openedAdd && rows.isEmpty) {
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

  void _shift(int days) {
    setState(() => _day = AppDate.addDays(_day, days));
    _load();
  }

  Future<void> _openAdd() async {
    final AppLocalizations l10n = context.l10n;
    final TextEditingController matricule = TextEditingController();
    final TextEditingController slot = TextEditingController();
    final TextEditingController start = TextEditingController();
    final TextEditingController end = TextEditingController();
    final TextEditingController hpad = TextEditingController();
    DateTime date = _day;
    List<Employee> suggestions = const <Employee>[];
    Employee? picked;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, void Function(void Function()) setSheet) {
          Future<void> pickDate() async {
            final DateTime? d = await showDatePicker(
              context: ctx,
              initialDate: date,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (d != null) setSheet(() => date = d);
          }

          Future<void> search(String q) async {
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
                  Text(l10n.addPermanence,
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(AppDate.format(date)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: matricule,
                    decoration: InputDecoration(
                      labelText: l10n.matricule,
                      hintText: l10n.searchEmployee,
                    ),
                    onChanged: (String v) {
                      picked = null;
                      search(v);
                    },
                  ),
                  if (suggestions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: AppSpacing.xs),
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: suggestions.length,
                        itemBuilder: (BuildContext c, int i) {
                          final Employee e = suggestions[i];
                          final String name =
                              Localizations.localeOf(c).languageCode == 'fr'
                                  ? e.displayName
                                  : e.displayNameAr;
                          return ListTile(
                            dense: true,
                            title: Text(name),
                            subtitle: Text(e.matricule),
                            onTap: () => setSheet(() {
                              picked = e;
                              matricule.text = e.matricule;
                              suggestions = const <Employee>[];
                            }),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: slot,
                    decoration: InputDecoration(labelText: l10n.timeRange),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: start,
                          decoration: InputDecoration(labelText: l10n.startTime),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextField(
                          controller: end,
                          decoration: InputDecoration(labelText: l10n.endTime),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: hpad,
                    decoration: InputDecoration(labelText: l10n.hpad),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: () async {
                      final String m = matricule.text.trim();
                      if (m.isEmpty && picked == null) {
                        showAppSnack(ctx, l10n.errFieldRequired, isError: true);
                        return;
                      }
                      try {
                        await ref.read(permanenceRepositoryProvider).insert(
                              PermanenceRecord(
                                date: AppDate.format(date),
                                employeeId: picked?.id,
                                matricule: m,
                                timeSlot: slot.text.trim(),
                                startTime: AppDate.normalizeTime(start.text),
                                endTime: AppDate.normalizeTime(end.text),
                                hpad: hpad.text.trim().isEmpty
                                    ? null
                                    : hpad.text.trim(),
                              ),
                            );
                        ref.read(dbRevisionProvider.notifier).bump();
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        setState(() => _day = date);
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
            ),
          );
        },
      ),
    );
  }

  Future<void> _remove(PermanenceRecord r) async {
    final AppLocalizations l10n = context.l10n;
    if (r.id == null) return;
    final bool ok = await confirmAction(
      context,
      title: l10n.delete,
      message: l10n.confirmDeleteMessage,
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(permanenceRepositoryProvider).remove(r.id!);
      ref.read(dbRevisionProvider.notifier).bump();
      if (!mounted) return;
      showAppSnack(context, l10n.deletedSuccessfully);
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, errorText(e, l10n), isError: true);
    }
  }

  Future<void> _link(PermanenceRecord r) async {
    final AppLocalizations l10n = context.l10n;
    if (r.id == null) return;
    final TextEditingController q = TextEditingController(text: r.matricule);
    List<Employee> found = const <Employee>[];

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, void Function(void Function()) setDialog) {
          return AlertDialog(
            title: Text(l10n.linkedTo),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: q,
                  decoration: InputDecoration(
                    labelText: l10n.matricule,
                    hintText: l10n.searchEmployee,
                  ),
                  onChanged: (String v) async {
                    final List<Employee> res =
                        await ref.read(employeeRepositoryProvider).suggest(v);
                    if (ctx.mounted) setDialog(() => found = res);
                  },
                ),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: found.length,
                    itemBuilder: (BuildContext c, int i) {
                      final Employee e = found[i];
                      return ListTile(
                        dense: true,
                        title: Text(e.displayNameAr),
                        subtitle: Text(e.matricule),
                        onTap: () async {
                          try {
                            await ref
                                .read(permanenceRepositoryProvider)
                                .link(r.id!, e.id!);
                            ref.read(dbRevisionProvider.notifier).bump();
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            _load();
                          } catch (err) {
                            if (ctx.mounted) {
                              showAppSnack(
                                ctx,
                                errorText(err, l10n),
                                isError: true,
                              );
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.cancel),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool isToday = _dateKey == AppDate.format(AppDate.today());

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.permanenceTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.addPermanence,
            icon: const Icon(Icons.add_task_outlined),
            onPressed: _openAdd,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addPermanence,
        onPressed: _openAdd,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: AppSpacing.page,
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip: l10n.prevDay,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shift(-1),
                ),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Text(
                        AppDate.displayLocalized(
                          _dateKey,
                          Localizations.localeOf(context).languageCode,
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (!isToday)
                        TextButton(
                          onPressed: () {
                            setState(() => _day = AppDate.today());
                            _load();
                          },
                          child: Text(l10n.today),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.nextDay,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _shift(1),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _error != null
                    ? ErrorView(error: _error!, onRetry: _load)
                    : _records.isEmpty
                        ? EmptyState(
                            icon: Icons.schedule_outlined,
                            title: l10n.noPermanence,
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
                              itemCount: _records.length,
                              itemBuilder: (BuildContext context, int i) {
                                final PermanenceRecord r = _records[i];
                                final bool unlinked = r.employeeId == null;
                                final String name = r.permanencier ??
                                    (r.employeeNameFr ?? r.employeeNameAr) ??
                                    r.matricule;
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: AppSpacing.xs,
                                  ),
                                  child: ListTile(
                                    title: Text(
                                      <String>[
                                        if (r.timeSlot.isNotEmpty) r.timeSlot,
                                        name,
                                      ].join(' • '),
                                    ),
                                    subtitle: Text(
                                      <String>[
                                        r.matricule,
                                        if ((r.section ?? '').isNotEmpty)
                                          r.section!,
                                        if (unlinked) l10n.unlinkedRecord,
                                        if ((r.scheduleText ?? '').isNotEmpty)
                                          r.scheduleText!,
                                      ].join(' • '),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        if (unlinked)
                                          IconButton(
                                            tooltip: l10n.linkedTo,
                                            icon: const Icon(Icons.link_outlined),
                                            color: AppColors.warning,
                                            onPressed: () => _link(r),
                                          ),
                                        IconButton(
                                          tooltip: l10n.delete,
                                          icon: const Icon(Icons.delete_outline),
                                          onPressed: () => _remove(r),
                                        ),
                                      ],
                                    ),
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
