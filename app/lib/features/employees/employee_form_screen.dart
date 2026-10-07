import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../localization/app_localizations_x.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/ui_kit.dart';
import '../../models/employee.dart';
import '../../models/reference_entries.dart';
import '../../repositories/employee_repository.dart';
import '../../repositories/reference_repository.dart';

/// إضافة موظف / تعديل بيانات موجود — بلا منطق أعمال.
class EmployeeFormScreen extends ConsumerStatefulWidget {
  const EmployeeFormScreen({super.key, this.employee});

  /// `null` = إضافة جديدة.
  final Employee? employee;

  @override
  ConsumerState<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends ConsumerState<EmployeeFormScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  late final TextEditingController _matricule;
  late final TextEditingController _nomAr;
  late final TextEditingController _prenomAr;
  late final TextEditingController _nomFr;
  late final TextEditingController _prenomFr;
  late final TextEditingController _quality;
  late final TextEditingController _ppr;
  late final TextEditingController _phone;
  late final TextEditingController _notes;

  List<ReferenceEntry> _sections = const <ReferenceEntry>[];
  List<ReferenceEntry> _grades = const <ReferenceEntry>[];
  List<ReferenceEntry> _functions = const <ReferenceEntry>[];

  int? _sectionId;
  int? _gradeId;
  int? _functionId;

  bool _loading = true;
  bool _saving = false;

  bool get _isNew => widget.employee == null;

  @override
  void initState() {
    super.initState();
    final Employee? e = widget.employee;
    _matricule = TextEditingController(text: e?.matricule ?? '');
    _nomAr = TextEditingController(text: e?.nomAr ?? '');
    _prenomAr = TextEditingController(text: e?.prenomAr ?? '');
    _nomFr = TextEditingController(text: e?.nomFr ?? '');
    _prenomFr = TextEditingController(text: e?.prenomFr ?? '');
    _quality = TextEditingController(text: e?.quality ?? '');
    _ppr = TextEditingController(text: e?.ppr ?? '');
    _phone = TextEditingController(text: e?.mobilePhone ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _sectionId = e?.sectionId;
    _gradeId = e?.gradeId;
    _functionId = e?.functionId;
    _loadReferences();
  }

  Future<void> _loadReferences() async {
    try {
      final ReferenceRepository refs = ref.read(referenceRepositoryProvider);
      final List<List<ReferenceEntry>> data = await Future.wait<List<ReferenceEntry>>(
        <Future<List<ReferenceEntry>>>[
          refs.sections(),
          refs.grades(),
          refs.functions(),
        ],
      );
      if (!mounted) return;
      setState(() {
        _sections = data[0];
        _grades = data[1];
        _functions = data[2];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[
      _matricule,
      _nomAr,
      _prenomAr,
      _nomFr,
      _prenomFr,
      _quality,
      _ppr,
      _phone,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate(AppLocalizations l10n) {
    if (Validators.matricule(_matricule.text) != null) {
      return l10n.errMatriculeRequired;
    }
    if (Validators.name(
          nomAr: _nomAr.text,
          prenomAr: _prenomAr.text,
          nomFr: _nomFr.text,
          prenomFr: _prenomFr.text,
        ) !=
        null) {
      return l10n.errNameRequired;
    }
    if (Validators.ppr(_ppr.text) != null) return l10n.errInvalidPpr;
    if (Validators.phone(_phone.text) != null) return l10n.errInvalidPhone;
    return null;
  }

  Future<void> _save() async {
    final AppLocalizations l10n = context.l10n;
    final String? invalid = _validate(l10n);
    if (invalid != null) {
      showAppSnack(context, invalid, isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final Employee base = widget.employee ?? Employee(matricule: '');
      final Employee next = base.copyWith(
        matricule: _matricule.text.trim(),
        nomAr: _nomAr.text.trim(),
        prenomAr: _prenomAr.text.trim(),
        nomFr: _nomFr.text.trim(),
        prenomFr: _prenomFr.text.trim(),
        quality: _quality.text.trim(),
        ppr: _ppr.text.trim(),
        mobilePhone: _phone.text.trim(),
        notes: _notes.text.trim(),
        sectionId: _sectionId,
        gradeId: _gradeId,
        functionId: _functionId,
        clearSection: _sectionId == null,
        clearGrade: _gradeId == null,
        clearFunction: _functionId == null,
      );

      final EmployeeRepository repo = ref.read(employeeRepositoryProvider);
      if (_isNew) {
        await repo.insert(next);
      } else {
        await repo.update(next);
      }
      ref.read(dbRevisionProvider.notifier).bump();
      if (!mounted) return;
      showAppSnack(context, l10n.savedSuccessfully);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnack(context, errorText(e, l10n), isError: true);
    }
  }

  Future<void> _archive() async {
    final AppLocalizations l10n = context.l10n;
    final Employee? e = widget.employee;
    if (e?.id == null) return;
    final bool ok = await confirmAction(
      context,
      title: l10n.confirmArchiveTitle,
      message: l10n.confirmArchiveMessage,
      confirmLabel: l10n.confirm,
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(employeeRepositoryProvider).deactivate(e!.id!);
      ref.read(dbRevisionProvider.notifier).bump();
      if (!mounted) return;
      showAppSnack(context, l10n.deletedSuccessfully);
      Navigator.of(context).pop(true);
    } catch (err) {
      if (!mounted) return;
      showAppSnack(context, errorText(err, l10n), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l10n.addEmployee : l10n.editEmployee),
        actions: <Widget>[
          if (!_isNew)
            IconButton(
              tooltip: l10n.delete,
              icon: const Icon(Icons.archive_outlined),
              onPressed: _archive,
            ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : Form(
              key: _form,
              child: ListView(
                padding: AppSpacing.page,
                children: <Widget>[
                  TextFormField(
                    controller: _matricule,
                    enabled: _isNew,
                    decoration: InputDecoration(
                      labelText: '${l10n.matricule} *',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _prenomAr,
                    decoration: InputDecoration(labelText: l10n.prenomAr),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _nomAr,
                    decoration: InputDecoration(labelText: l10n.nomAr),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _prenomFr,
                    decoration: InputDecoration(labelText: l10n.prenomFr),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _nomFr,
                    decoration: InputDecoration(labelText: l10n.nomFr),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<int?>(
                    initialValue: _sectionId,
                    decoration: InputDecoration(labelText: l10n.chooseSection),
                    items: <DropdownMenuItem<int?>>[
                      const DropdownMenuItem<int?>(value: null, child: Text('—')),
                      for (final ReferenceEntry r in _sections)
                        DropdownMenuItem<int?>(
                          value: r.id,
                          child: Text(lang == 'fr' ? r.name : (r.nameAr ?? r.name)),
                        ),
                    ],
                    onChanged: (int? v) => setState(() => _sectionId = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<int?>(
                    initialValue: _gradeId,
                    decoration: InputDecoration(labelText: l10n.chooseGrade),
                    items: <DropdownMenuItem<int?>>[
                      const DropdownMenuItem<int?>(value: null, child: Text('—')),
                      for (final ReferenceEntry r in _grades)
                        DropdownMenuItem<int?>(
                          value: r.id,
                          child: Text(lang == 'fr' ? r.name : (r.nameAr ?? r.name)),
                        ),
                    ],
                    onChanged: (int? v) => setState(() => _gradeId = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<int?>(
                    initialValue: _functionId,
                    decoration: InputDecoration(labelText: l10n.chooseFunction),
                    items: <DropdownMenuItem<int?>>[
                      const DropdownMenuItem<int?>(value: null, child: Text('—')),
                      for (final ReferenceEntry r in _functions)
                        DropdownMenuItem<int?>(
                          value: r.id,
                          child: Text(lang == 'fr' ? r.name : (r.nameAr ?? r.name)),
                        ),
                    ],
                    onChanged: (int? v) => setState(() => _functionId = v),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _quality,
                    decoration: InputDecoration(labelText: l10n.quality),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _ppr,
                    decoration: InputDecoration(labelText: l10n.ppr),
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _phone,
                    decoration: InputDecoration(labelText: l10n.mobilePhone),
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _notes,
                    maxLines: 3,
                    decoration: InputDecoration(labelText: l10n.notes),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.save),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                ],
              ),
            ),
    );
  }
}
