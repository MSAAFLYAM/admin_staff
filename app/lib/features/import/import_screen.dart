import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../localization/app_localizations_x.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_date.dart';
import '../../core/widgets/ui_kit.dart';
import '../../services/csv_column_mapper.dart';
import '../../services/import/import_models.dart';

/// معالج الاستيراد: نوع ← ملف ← معاينة ← تنفيذ (Transaction واحدة).
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  ImportKind _kind = ImportKind.employees;
  ImportMode _mode = ImportMode.addNew;
  String? _fileName;
  List<int>? _bytes;
  ImportPreview? _preview;
  ImportResult? _result;
  String? _error;
  bool _busy = false;

  DateTime? _replaceFrom;
  DateTime? _replaceTo;

  Future<void> _pickFile() async {
    final AppLocalizations l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _preview = null;
    });
    try {
      final List<PlatformFile> files =
          await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      final PlatformFile file = files.first;
      final List<int> bytes = await file.readAsBytes();
      setState(() {
        _bytes = bytes;
        _fileName = file.name;
      });
      await _previewFile();
    } catch (e) {
      setState(() {
        _busy = false;
        _error = errorText(e, l10n);
      });
    }
  }

  Future<void> _previewFile() async {
    final AppLocalizations l10n = context.l10n;
    final List<int>? bytes = _bytes;
    final String? name = _fileName;
    if (bytes == null || name == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ImportPreview p = await ref.read(csvImportServiceProvider).preview(
            kind: _kind,
            bytes: bytes,
            fileName: name,
            mode: _mode,
          );
      if (!mounted) return;
      setState(() {
        _preview = p;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _busy = false;
        _error = errorText(e, l10n);
      });
    }
  }

  Future<void> _commit() async {
    final AppLocalizations l10n = context.l10n;
    final ImportPreview? p = _preview;
    if (p == null) return;

    if (_mode == ImportMode.replaceRange &&
        (_replaceFrom == null || _replaceTo == null)) {
      showAppSnack(context, l10n.errFieldRequired, isError: true);
      return;
    }
    final bool ok = await confirmAction(
      context,
      title: l10n.confirmImport,
      message: _mode == ImportMode.replaceRange
          ? l10n.replaceWarning
          : '${l10n.totalRows}: ${p.totalRows}',
      confirmLabel: l10n.confirm,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final ImportResult r =
          await ref.read(csvImportServiceProvider).commit(
                p,
                mode: _mode,
                replaceFrom: _replaceFrom == null
                    ? null
                    : AppDate.format(_replaceFrom!),
                replaceTo:
                    _replaceTo == null ? null : AppDate.format(_replaceTo!),
              );
      ref.read(dbRevisionProvider.notifier).bump();
      if (!mounted) return;
      setState(() {
        _result = r;
        _busy = false;
        _preview = null;
      });
      showAppSnack(context, l10n.importSucceeded);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorText(e, l10n);
      });
    }
  }

  Future<void> _pickRange(bool isFrom) async {
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_replaceFrom ?? AppDate.today()) : (_replaceTo ?? AppDate.today()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() {
      if (isFrom) {
        _replaceFrom = d;
      } else {
        _replaceTo = d;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ImportPreview? p = _preview;
    final ImportResult? r = _result;
    final List<TargetField> fields = _kind == ImportKind.employees
        ? CsvColumnMapper.employeeFields
        : CsvColumnMapper.permanenceFields;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.importTitle)),
      body: ListView(
        padding: AppSpacing.page,
        children: <Widget>[
          // ── نوع الملف ──
          SectionCard(
            title: l10n.importTitle,
            children: <Widget>[
              SegmentedButton<ImportKind>(
                segments: <ButtonSegment<ImportKind>>[
                  ButtonSegment<ImportKind>(
                    value: ImportKind.employees,
                    label: Text(l10n.importEmployees),
                    icon: const Icon(Icons.people_outline),
                  ),
                  ButtonSegment<ImportKind>(
                    value: ImportKind.permanence,
                    label: Text(l10n.importPermanence),
                    icon: const Icon(Icons.schedule_outlined),
                  ),
                ],
                selected: <ImportKind>{_kind},
                onSelectionChanged: (Set<ImportKind> s) {
                  setState(() {
                    _kind = s.first;
                    _preview = null;
                    _fileName = null;
                    _bytes = null;
                  });
                },
              ),
              if (_kind == ImportKind.permanence) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                SegmentedButton<ImportMode>(
                  segments: <ButtonSegment<ImportMode>>[
                    ButtonSegment<ImportMode>(
                      value: ImportMode.addNew,
                      label: Text(l10n.modeAddWeek),
                    ),
                    ButtonSegment<ImportMode>(
                      value: ImportMode.updateExisting,
                      label: Text(l10n.modeUpdateWeek),
                    ),
                    ButtonSegment<ImportMode>(
                      value: ImportMode.replaceRange,
                      label: Text(l10n.modeReplaceRange),
                    ),
                  ],
                  selected: <ImportMode>{_mode},
                  onSelectionChanged: (Set<ImportMode> s) {
                    setState(() {
                      _mode = s.first;
                      _preview = null;
                    });
                  },
                ),
                if (_mode == ImportMode.replaceRange) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Text(l10n.replaceWarning,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickRange(true),
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(_replaceFrom == null
                              ? l10n.from
                              : AppDate.format(_replaceFrom!)),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickRange(false),
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(_replaceTo == null
                              ? l10n.to
                              : AppDate.format(_replaceTo!)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: _busy ? null : _pickFile,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(_fileName == null
                    ? l10n.selectFile
                    : '${l10n.fileName}: $_fileName'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          if (_error != null)
            SectionCard(
              title: l10n.invalidRowsTitle,
              children: <Widget>[
                Text(_error!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.danger)),
              ],
            ),

          if (_busy) ...<Widget>[
            const LoadingView(),
            const SizedBox(height: AppSpacing.lg),
          ],

          // ── المعاينة ──
          if (p != null) ...<Widget>[
            SectionCard(
              title: l10n.previewTitle,
              children: <Widget>[
                if (p.detectedDateFormat != null)
                  InfoRow(label: l10n.dateFormat, value: p.detectedDateFormat),
                InfoRow(label: l10n.totalRows, value: '${p.totalRows}'),
                InfoRow(label: l10n.newRows, value: '${p.insertCount}'),
                InfoRow(label: l10n.updatedRows, value: '${p.updateCount}'),
                InfoRow(
                  label: l10n.duplicateRows,
                  value:
                      '${p.duplicateInFileCount + p.duplicateExistingCount}',
                ),
                InfoRow(label: l10n.errorRows, value: '${p.errorCount}'),
                if (p.unmatched.isNotEmpty)
                  InfoRow(
                    label: l10n.unmatchedEmployees,
                    value: '${p.unmatched.length}',
                  ),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.columnMapping,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: <Widget>[
                    for (final TargetField f in fields)
                      if ((p.mapping as ColumnMapping).isAssigned(f.key))
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            '${f.key} ← '
                            '${p.parsed.headers[(p.mapping as ColumnMapping).columnFor(f.key)!]}',
                          ),
                        ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            if (p.rejected().isNotEmpty)
              SectionCard(
                title: '${l10n.rejectedRows} (${p.errorCount})',
                children: <Widget>[
                  for (final PlannedRow row in p.rejected(max: 30))
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Text(
                        '${l10n.rowNumber(row.lineNumber)} — '
                        '${row.errorMessage ?? l10n.errUnknown}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.danger),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.lg),

            FilledButton.icon(
              onPressed: _busy ? null : _commit,
              icon: const Icon(Icons.done_all),
              label: Text(l10n.confirmImport),
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],

          // ── النتيجة ──
          if (r != null)
            SectionCard(
              title: l10n.importSucceeded,
              children: <Widget>[
                InfoRow(label: l10n.newRows, value: '${r.inserted}'),
                InfoRow(label: l10n.updatedRows, value: '${r.updated}'),
                InfoRow(label: l10n.validRows, value: '${r.skipped}'),
                InfoRow(label: l10n.errorRows, value: '${r.errors}'),
                if (r.referenceEntriesCreated > 0)
                  InfoRow(
                    label: l10n.sectionReferences,
                    value: '${r.referenceEntriesCreated}',
                  ),
                if (r.message != null && r.message!.isNotEmpty)
                  Text(r.message!,
                      style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
        ],
      ),
    );
  }
}
