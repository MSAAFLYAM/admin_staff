import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../localization/app_localizations_x.dart';
import '../../core/constants/db_constants.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/ui_kit.dart';
import '../../models/reference_entries.dart';
import '../../repositories/reference_repository.dart';

/// إدارة المراجع: الأقسام / الدرجات / الوظائف (إضافة + تفعيل/تعطيل).
class ReferencesScreen extends ConsumerStatefulWidget {
  const ReferencesScreen({super.key});

  @override
  ConsumerState<ReferencesScreen> createState() => _ReferencesScreenState();
}

class _ReferencesScreenState extends ConsumerState<ReferencesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sectionReferences),
        bottom: TabBar(
          controller: _tabs,
          tabs: <Widget>[
            Tab(text: l10n.sections),
            Tab(text: l10n.grades),
            Tab(text: l10n.functionsList),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: <Widget>[
          _ReferenceList(table: Db.sections, title: l10n.addSection),
          _ReferenceList(table: Db.grades, title: l10n.addGrade),
          _ReferenceList(table: Db.functions, title: l10n.addFunction),
        ],
      ),
    );
  }
}

class _ReferenceList extends ConsumerStatefulWidget {
  const _ReferenceList({required this.table, required this.title});

  final String table;
  final String title;

  @override
  ConsumerState<_ReferenceList> createState() => _ReferenceListState();
}

class _ReferenceListState extends ConsumerState<_ReferenceList> {
  List<ReferenceEntry> _items = const <ReferenceEntry>[];
  bool _loading = true;
  Object? _error;
  bool _showInactive = false;

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
      final ReferenceRepository repo = ref.read(referenceRepositoryProvider);
      final List<ReferenceEntry> rows = switch (widget.table) {
        Db.sections => await repo.sections(),
        Db.grades => await repo.grades(),
        _ => await repo.functions(),
      };
      if (!mounted) return;
      setState(() {
        _items = rows;
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

  Future<void> _add() async {
    final AppLocalizations l10n = context.l10n;
    final TextEditingController name = TextEditingController();
    final TextEditingController nameAr = TextEditingController();

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: l10n.name),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: nameAr,
              decoration: InputDecoration(labelText: l10n.nomAr),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(referenceRepositoryProvider).createEntry(
            widget.table,
            name.text,
            nameAr: nameAr.text,
          );
      ref.read(dbRevisionProvider.notifier).bump();
      if (!mounted) return;
      showAppSnack(context, l10n.savedSuccessfully);
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, errorText(e, l10n), isError: true);
    }
  }

  Future<void> _toggle(ReferenceEntry e) async {
    if (e.id == null) return;
    try {
      await ref.read(referenceRepositoryProvider).upsertEntry(
            widget.table,
            id: e.id,
            name: e.name,
            nameAr: e.nameAr,
            isActive: !e.isActive,
          );
      ref.read(dbRevisionProvider.notifier).bump();
      _load();
    } catch (err) {
      if (!mounted) return;
      showAppSnack(context, errorText(err, context.l10n), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String lang = Localizations.localeOf(context).languageCode;

    if (_loading) return const LoadingView();
    if (_error != null) {
      return ErrorView(error: _error!, onRetry: _load);
    }

    final List<ReferenceEntry> visible = _showInactive
        ? _items
        : _items.where((ReferenceEntry e) => e.isActive).toList();

    if (visible.isEmpty) {
      return EmptyState(
        icon: Icons.list_alt_outlined,
        title: l10n.noResults,
        action: FilledButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: Text(widget.title),
        ),
      );
    }

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Text('${visible.length}', style: Theme.of(context).textTheme.bodySmall),
              const Spacer(),
              FilterChip(
                label: Text(l10n.showInactive),
                selected: _showInactive,
                onSelected: (bool v) => setState(() => _showInactive = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              itemCount: visible.length,
              itemBuilder: (BuildContext context, int i) {
                final ReferenceEntry e = visible[i];
                final String label =
                    lang == 'fr' ? e.name : (e.nameAr ?? e.name);
                return ListTile(
                  dense: true,
                  title: Text(label, style: TextStyle(
                    color: e.isActive ? null : Theme.of(context).textTheme.bodySmall?.color,
                  )),
                  subtitle: (lang == 'fr' && e.nameAr != null)
                      ? Text(e.nameAr!)
                      : null,
                  trailing: IconButton(
                    tooltip: e.isActive ? l10n.deactivate : l10n.reactivate,
                    icon: Icon(
                      e.isActive ? Icons.toggle_on_outlined : Icons.toggle_off_outlined,
                      color: e.isActive ? null : Theme.of(context).hintColor,
                    ),
                    onPressed: () => _toggle(e),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: Text(widget.title),
            ),
          ),
        ),
      ],
    );
  }
}
