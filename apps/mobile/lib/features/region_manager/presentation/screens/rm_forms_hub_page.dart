import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../forms/domain/models/form_models.dart';
import '../../../forms/presentation/providers/forms_providers.dart';
import '../../domain/providers/region_manager_providers.dart';
import 'rm_form_fill_page.dart';
import 'rm_completed_forms_page.dart';

/// Bölge Müdürü Form Modülü Ana Sayfası - Tab yapısında
class RmFormsHubPage extends ConsumerStatefulWidget {
  const RmFormsHubPage({super.key});

  @override
  ConsumerState<RmFormsHubPage> createState() => _RmFormsHubPageState();
}

class _RmFormsHubPageState extends ConsumerState<RmFormsHubPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mağaza Puanlama'),
      ),
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: theme.colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurface.withAlpha(150),
              indicatorColor: theme.colorScheme.primary,
              tabs: const [
                Tab(
                  icon: Icon(Icons.assignment_outlined),
                  text: 'Formlar',
                ),
                Tab(
                  icon: Icon(Icons.check_circle_outline),
                  text: 'Tamamlananlar',
                ),
              ],
            ),
          ),
          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _RmFormsListTab(),
                RmCompletedFormsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Doldurulabilir formlar listesi - Bölge Müdürü için
class _RmFormsListTab extends ConsumerWidget {
  const _RmFormsListTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formsAsync = ref.watch(publishedFormsProvider);
    final branchesAsync = ref.watch(regionManagerBranchesProvider);
    final theme = Theme.of(context);

    return formsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Formlar yüklenemedi',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(150),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(publishedFormsProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
      data: (forms) {
        // Şubelerin yüklenmesini de kontrol et
        final branches = branchesAsync.maybeWhen(
          data: (data) => data,
          orElse: () => null,
        );

        if (branches == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (branches.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.store_outlined,
                  size: 64,
                  color: theme.colorScheme.onSurface.withAlpha(100),
                ),
                const SizedBox(height: 16),
                Text(
                  'Yönettiğiniz şube bulunmuyor',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                ),
              ],
            ),
          );
        }

        if (forms.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 64,
                  color: theme.colorScheme.onSurface.withAlpha(100),
                ),
                const SizedBox(height: 16),
                Text(
                  'Henüz form tanımlanmamış',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Yöneticiniz form oluşturduğunda burada görünecek.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(100),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(publishedFormsProvider);
            ref.invalidate(regionManagerBranchesProvider);
            await ref.read(publishedFormsProvider.future);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: forms.length,
            itemBuilder: (context, index) {
              final form = forms[index];
              return _RmFormCard(form: form);
            },
          ),
        );
      },
    );
  }
}

/// Form kartı widget'ı - Bölge Müdürü için
class _RmFormCard extends StatelessWidget {
  const _RmFormCard({required this.form});

  final PublishedForm form;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RmFormFillPage(form: form),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.assignment,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          form.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (form.code.isNotEmpty)
                          Text(
                            form.code,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(150),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: theme.colorScheme.onSurface.withAlpha(100),
                  ),
                ],
              ),
              if (form.description != null && form.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  form.description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(150),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.format_list_numbered,
                    label: '${form.totalItemCount} soru',
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.category_outlined,
                    label: '${form.sections.length} bölüm',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: theme.colorScheme.onSurface.withAlpha(150),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }
}
