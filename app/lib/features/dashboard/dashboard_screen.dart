import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../localization/app_localizations_x.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/app_date.dart';
import '../../core/widgets/ui_kit.dart';
import '../../models/status_type.dart';
import '../../repositories/dashboard_repository.dart';
import '../employees/employee_form_screen.dart';
import '../employees/employees_screen.dart';
import '../import/import_screen.dart';
import '../leaves/leaves_screen.dart';
import '../permanence/permanence_screen.dart';

/// ملخّص لوحة القيادة (يُعاد تحميله بعد كل كتابة عبر [dbRevisionProvider]).
final FutureProvider<DashboardSummary> dashboardSummaryProvider =
    FutureProvider<DashboardSummary>((ref) {
  ref.watch(dbRevisionProvider);
  return ref.watch(dashboardRepositoryProvider).summary();
});

/// كل أنواع الوضعيات (للعناوين — أسماء من القاعدة لا من الكود).
final FutureProvider<List<StatusType>> statusTypesProvider =
    FutureProvider<List<StatusType>>((
  ref,
) {
  ref.watch(dbRevisionProvider);
  return ref.watch(referenceRepositoryProvider).statusTypes();
});

/// التبويب الأول: لوحة القيادة.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => screen,
      ));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<DashboardSummary> summary =
        ref.watch(dashboardSummaryProvider);
    final AsyncValue<List<StatusType>> statuses = ref.watch(statusTypesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dashboardTitle)),
      body: summary.when(
        loading: () => const LoadingView(),
        error: (Object e, StackTrace _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(dashboardSummaryProvider),
        ),
        data: (DashboardSummary data) => RefreshIndicator(
          onRefresh: () async {
            ref
              ..invalidate(dashboardSummaryProvider)
              ..invalidate(statusTypesProvider);
            await ref.read(dashboardSummaryProvider.future);
          },
          child: ListView(
            padding: AppSpacing.page,
            children: <Widget>[
              // ── الأرقام الأساسية ──
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 1.6,
                children: <Widget>[
                  StatCard(
                    label: l10n.totalEmployees,
                    value: '${data.totalEmployees}',
                    icon: Icons.people_alt_outlined,
                    color: AppColors.neon,
                    onTap: () => _open(context, const EmployeesScreen()),
                  ),
                  StatCard(
                    label: l10n.archivedCount,
                    value: '${data.archivedCount}',
                    icon: Icons.archive_outlined,
                    color: AppColors.neutral,
                  ),
                  StatCard(
                    label: l10n.todaysPermanence,
                    value: '${data.todaysPermanence}',
                    icon: Icons.schedule_outlined,
                    color: AppColors.info,
                    onTap: () => _open(context, const PermanenceScreen()),
                  ),
                  StatCard(
                    label: l10n.leavesEndingToday,
                    value: '${data.leavesEndingToday}',
                    icon: Icons.event_available_outlined,
                    color: AppColors.warning,
                    onTap: () => _open(context, const LeavesScreen()),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── الوضعيات ──
              statuses.maybeWhen(
                data: (List<StatusType> types) => SectionCard(
                  title: l10n.status,
                  children: <Widget>[
                    if (types.isEmpty)
                      Text(l10n.noResults,
                          style: Theme.of(context).textTheme.bodyMedium)
                    else
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: <Widget>[
                          for (final StatusType t in types)
                            Chip(
                              avatar: CircleAvatar(
                                backgroundColor:
                                    AppColors.chart(t.id ?? 0),
                                radius: 6,
                              ),
                              label: Text(
                                '${t.name} — '
                                '${data.statusCounts[t.id] ?? 0}',
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── تنبيهات اليوم ──
              SectionCard(
                title: l10n.todaysAlerts,
                children: <Widget>[
                  _AlertTile(
                    icon: Icons.logout_outlined,
                    label: l10n.leavesEndingToday,
                    count: data.leavesEndingToday,
                  ),
                  _AlertTile(
                    icon: Icons.event_available_outlined,
                    label: l10n.leavesEndingTomorrow,
                    count: data.leavesEndingTomorrow,
                  ),
                  _AlertTile(
                    icon: Icons.event_outlined,
                    label: l10n.leavesEndingIn3Days,
                    count: data.leavesEndingIn3Days,
                  ),
                  _AlertTile(
                    icon: Icons.login_outlined,
                    label: l10n.employeesReturningToday,
                    count: data.returningToday,
                  ),
                  _AlertTile(
                    icon: Icons.link_off_outlined,
                    label: l10n.unmatchedEmployees,
                    count: data.unmatchedToday,
                  ),
                  if (data.leavesEndingToday == 0 &&
                      data.leavesEndingTomorrow == 0 &&
                      data.leavesEndingIn3Days == 0 &&
                      data.returningToday == 0 &&
                      data.unmatchedToday == 0)
                    Text(l10n.noAlertsToday,
                        style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── إجراءات سريعة ──
              SectionCard(
                title: l10n.quickActions,
                children: <Widget>[
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: () =>
                            _open(context, const ImportScreen()),
                        icon: const Icon(Icons.upload_file_outlined),
                        label: Text(l10n.importTitle),
                      ),
                      FilledButton.icon(
                        onPressed: () => _open(
                          context,
                          const EmployeeFormScreen(),
                        ),
                        icon: const Icon(Icons.person_add_alt_outlined),
                        label: Text(l10n.addEmployee),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _open(
                          context,
                          const PermanenceScreen(addOnStart: true),
                        ),
                        icon: const Icon(Icons.add_task_outlined),
                        label: Text(l10n.addPermanence),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _open(
                          context,
                          const LeavesScreen(addOnStart: true),
                        ),
                        icon: const Icon(Icons.beach_access_outlined),
                        label: Text(l10n.addLeave),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── تاريخ اليوم ──
              Center(
                child: Text(
                  AppDate.displayLocalized(
                    AppDate.format(AppDate.today()),
                    Localizations.localeOf(context).languageCode,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final bool none = count == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          Icon(
            icon,
            size: 18,
            color: none ? AppColors.textTertiary : AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label)),
          Text(
            '$count',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: none ? AppColors.textTertiary : AppColors.warning,
                ),
          ),
        ],
      ),
    );
  }
}
