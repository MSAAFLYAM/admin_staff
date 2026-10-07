import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../localization/app_localizations_x.dart';
import '../../core/providers/app_providers.dart';
import '../../core/query/search_query.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/ui_kit.dart';
import '../../models/employee.dart';
import '../../models/reference_entries.dart';
import '../../models/status_type.dart';
import '../../repositories/employee_repository.dart';
import '../../repositories/reference_repository.dart';
import '../import/import_screen.dart';
import 'employee_form_screen.dart';
import 'employee_profile_screen.dart';

/// شاشة الموظفين: بحث + تصفية + قائمة مُرقَّمة.
class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key, this.initialText});

  /// نص بحث افتراضي (عند الجلوس من لوحة القيادة).
  final String? initialText;

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  static const int _limit = 50;

  late final TextEditingController _search;
  final ScrollController _scroll = ScrollController();

  final List<FilterCriterion> _criteria = <FilterCriterion>[];
  bool _includeInactive = false;

  final List<Employee> _items = <Employee>[];
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;

  /// رقم الطلب الجاري — النتائج الأقدم تُهمَش حتى لا تطغى على الأحدث.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialText ?? '');
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  SearchQuery get _query => SearchQuery(
        text: _search.text,
        filters: FilterSet(criteria: _criteria),
        includeInactive: _includeInactive,
        limit: _limit,
        offset: _items.length,
      );

  Future<void> _load({bool reset = false}) async {
    final int request = ++_request;
    if (reset) {
      _items.clear();
      _error = null;
      _loading = true;
      setState(() {});
    } else {
      if (_loadingMore) return;
      _loadingMore = true;
      setState(() {});
    }
    try {
      final EmployeePage page =
          await ref.read(employeeRepositoryProvider).search(_query);
      if (!mounted || request != _request) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _total = page.total;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = e;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final double max = _scroll.position.maxScrollExtent;
    if (_scroll.offset >= max - 200 && !_loadingMore && _items.length < _total) {
      _load();
    }
  }

  Future<void> _openFilterSheet() async {
    final AppLocalizations l10n = context.l10n;
    final ReferenceRepository refs = ref.read(referenceRepositoryProvider);
    final List<ReferenceEntry> sections = await refs.sections();
    final List<ReferenceEntry> grades = await refs.grades();
    final List<StatusType> statuses = await refs.statusTypes();
    if (!mounted) return;

    final List<FilterCriterion> draft = List<FilterCriterion>.of(_criteria);
    bool draftInactive = _includeInactive;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, void Function(void Function()) setSheet) {
          FilterCriterion? findCriterion(FilterField f) {
            for (final FilterCriterion c in draft) {
              if (c.field == f) return c;
            }
            return null;
          }

          void setCriterion(FilterField f, int? id) {
            draft.removeWhere((FilterCriterion c) => c.field == f);
            if (id != null) {
              draft.add(FilterCriterion(
                field: f,
                operator: FilterOperator.eq,
                value: '$id',
              ));
            }
          }

          Widget buildDropdown({
            required String label,
            required FilterField field,
            required List<({int id, String name})> options,
          }) {
            final FilterCriterion? current = findCriterion(field);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: DropdownButtonFormField<int?>(
                initialValue: current == null ? null : int.tryParse(current.value ?? ''),
                decoration: InputDecoration(labelText: label),
                items: <DropdownMenuItem<int?>>[
                  const DropdownMenuItem<int?>(value: null, child: Text('—')),
                  for (final ({int id, String name}) o in options)
                    DropdownMenuItem<int?>(value: o.id, child: Text(o.name)),
                ],
                onChanged: (int? v) => setSheet(() => setCriterion(field, v)),
              ),
            );
          }

          final String lang = Localizations.localeOf(ctx).languageCode;

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
                Text(l10n.filter, style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.md),
                buildDropdown(
                  label: l10n.chooseSection,
                  field: FilterField.section,
                  options: <({int id, String name})>[
                    for (final ReferenceEntry e in sections)
                      (id: e.id ?? -1, name: lang == 'fr' ? e.name : (e.nameAr ?? e.name)),
                  ],
                ),
                buildDropdown(
                  label: l10n.chooseGrade,
                  field: FilterField.grade,
                  options: <({int id, String name})>[
                    for (final ReferenceEntry e in grades)
                      (id: e.id ?? -1, name: lang == 'fr' ? e.name : (e.nameAr ?? e.name)),
                  ],
                ),
                buildDropdown(
                  label: l10n.chooseStatus,
                  field: FilterField.status,
                  options: <({int id, String name})>[
                    for (final StatusType s in statuses)
                      (id: s.id ?? -1, name: lang == 'fr' ? (s.nameFr ?? s.name) : s.name),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.showInactive),
                  value: draftInactive,
                  onChanged: (bool v) => setSheet(() => draftInactive = v),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setSheet(() {
                          draft.clear();
                          draftInactive = false;
                        }),
                        child: Text(l10n.clear),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          setState(() {
                            _criteria
                              ..clear()
                              ..addAll(draft);
                            _includeInactive = draftInactive;
                          });
                          _load(reset: true);
                        },
                        child: Text(l10n.apply),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openForm({Employee? employee}) async {
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EmployeeFormScreen(employee: employee),
      ),
    );
    if (saved == true) {
      ref.read(dbRevisionProvider.notifier).bump();
      _load(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.employeesTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.importTitle,
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(builder: (_) => const ImportScreen()),
            ),
          ),
          IconButton(
            tooltip: l10n.filter,
            icon: Icon(
              Icons.filter_list_outlined,
              color: _criteria.isEmpty ? null : AppColors.neon,
            ),
            onPressed: _openFilterSheet,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addEmployee,
        onPressed: () => _openForm(),
        child: const Icon(Icons.person_add_alt_outlined),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.searchPlaceholder,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                          _load(reset: true);
                        },
                      ),
              ),
              onChanged: (_) {
                setState(() {});
                _load(reset: true);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: <Widget>[
                Text(
                  l10n.searchResultsCount(_total),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                if (_criteria.isNotEmpty)
                  ActionChip(
                    label: Text(l10n.clear),
                    onPressed: () {
                      setState(_criteria.clear);
                      _load(reset: true);
                    },
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _error != null
                    ? ErrorView(
                        error: _error!,
                        onRetry: () => _load(reset: true),
                      )
                    : _items.isEmpty
                        ? EmptyState(
                            icon: Icons.people_outline,
                            title: l10n.noResults,
                            hint: l10n.noResultsHint,
                          )
                        : RefreshIndicator(
                            onRefresh: () => _load(reset: true),
                            child: ListView.builder(
                              controller: _scroll,
                              padding:
                                  const EdgeInsets.fromLTRB(0, 0, 0, 88),
                              itemCount: _items.length + 1,
                              itemBuilder: (BuildContext context, int i) {
                                if (i == _items.length) {
                                  if (!_loadingMore) return const SizedBox.shrink();
                                  return const Padding(
                                    padding: EdgeInsets.all(AppSpacing.md),
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child:
                                            CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  );
                                }
                                return _EmployeeTile(
                                  employee: _items[i],
                                  onTap: () => Navigator.of(context).push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (_) => EmployeeProfileScreen(
                                        employeeId: _items[i].id!,
                                      ),
                                    ),
                                  ),
                                  onEdit: () => _openForm(employee: _items[i]),
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

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({
    required this.employee,
    required this.onTap,
    required this.onEdit,
  });

  final Employee employee;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final String lang = Localizations.localeOf(context).languageCode;
    final String name = lang == 'fr' ? employee.displayName : employee.displayNameAr;
    final String status = employee.displayStatus;

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.neonSurface,
          foregroundColor: AppColors.neon,
          child: Text(
            employee.matricule.isEmpty
                ? '?'
                : employee.matricule.substring(0, 1).toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          <String>[
            employee.matricule,
            if (employee.sectionName != null) employee.sectionName!,
            if (status.isNotEmpty) status,
          ].join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: onEdit,
        ),
      ),
    );
  }
}
