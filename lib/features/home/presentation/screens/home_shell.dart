import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yotech_mobile/features/skt/presentation/screens/skt_list_page.dart';
import 'package:yotech_mobile/core/features/feature_repo.dart';
import 'package:yotech_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:yotech_mobile/features/settings/presentation/screens/settings_page.dart';
import 'package:yotech_mobile/shared/widgets/custom_back_button.dart';
import 'package:yotech_mobile/features/auth/domain/providers/auth_provider.dart';

class FeatureKeys {
  static const skt = 'skt';
  static const forms = 'forms';
  static const shifts = 'shifts';
  static const announcements = 'announcements';
  static const tasks = 'tasks';
  static const interbranchTransfer = 'interbranch_transfer';
  static const leaveRequest = 'leave_request';
  static const breakTracking = 'break_tracking';
  static const itTicket = 'it_ticket';
  static const instoreShortage = 'instore_shortage';
  static const timeAttendance = 'time_attendance';
  static const merchandising = 'merchandising';
  static const profile = 'profile';
  static const requests = 'requests';
}

class ShortcutOrderStore {
  static String _key(String tenantId) => 'shortcut_order_$tenantId';

  static Future<List<String>> load(String tenantId) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key(tenantId));
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return <String>[];
    }
  }

  static Future<void> save(String tenantId, List<String> order) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key(tenantId), jsonEncode(order));
  }
}

class FeatureEntry {
  final String key;
  final String title;
  final IconData icon;
  FeatureEntry(this.key, this.title, this.icon);
}

FeatureEntry _entryFor(String key) {
  switch (key) {
    case FeatureKeys.skt:
      return FeatureEntry(key, 'SKT', Icons.calendar_month);
    case 'depo':
      return FeatureEntry('depo', 'Depo', Icons.warehouse);
    case FeatureKeys.merchandising:
      return FeatureEntry(key, 'Mörş', Icons.shopping_bag);
    case FeatureKeys.forms:
      return FeatureEntry(key, 'Formlar', Icons.assignment);
    case FeatureKeys.shifts:
      return FeatureEntry(key, 'Vardiya', Icons.schedule);
    case FeatureKeys.announcements:
      return FeatureEntry(key, 'Duyurular', Icons.campaign);
    case FeatureKeys.tasks:
      return FeatureEntry(key, 'Görevler', Icons.checklist);
    case FeatureKeys.requests:
      return FeatureEntry(key, 'Talepler', Icons.inbox);
    case FeatureKeys.breakTracking:
      return FeatureEntry(key, 'Mola', Icons.timer);
    case FeatureKeys.timeAttendance:
      return FeatureEntry(key, 'Puantaj', Icons.fingerprint);
    case FeatureKeys.profile:
      return FeatureEntry(key, 'Profil', Icons.person);
    default:
      return FeatureEntry(key, key, Icons.extension);
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final _sheetCtrl = DraggableScrollableController();
  List<String> _order = [];
  String? _activePageKey;

  // Tek kaynaktan kontrol
  static const double kMinSheetSize = 0.12;
  static const double kMaxSheetSize = 0.45;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _sheetCtrl.animateTo(
          kMinSheetSize,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
        );
      } catch (_) {}
    });
    _loadShortcutOrder();
  }

  Future<void> _loadShortcutOrder() async {
    final authState = ref.read(authProvider);
    await authState.whenOrNull(
      authenticated: (user) async {
        _order = await ShortcutOrderStore.load(user.tenantId);
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _persistOrder() async {
    final authState = ref.read(authProvider);
    await authState.whenOrNull(
      authenticated: (user) async {
        await ShortcutOrderStore.save(user.tenantId, _order);
      },
    );
  }

  @override
  void dispose() {
    _sheetCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Çıkış yapılsın mı?'),
        content: const Text('Oturum kapatılıp giriş ekranına dönülecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Çıkış'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await ref.read(authProvider.notifier).logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final asyncFeatures = ref.watch(effectiveFeaturesProvider);

    return authState.when(
      authenticated: (user) {
        return asyncFeatures.when(
          loading: () => const Scaffold(
            body: SafeArea(child: Center(child: CircularProgressIndicator())),
          ),
          error: (e, _) => Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Özellikler yüklenemedi.\n$e',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          data: (features) {
            bool has(String k) => features[k] == true;
            final showDepo = has(FeatureKeys.instoreShortage) ||
                has(FeatureKeys.interbranchTransfer);
            final showRequests =
                has(FeatureKeys.leaveRequest) || has(FeatureKeys.itTicket);

            final activeKeys = <String>[
              if (has(FeatureKeys.skt)) FeatureKeys.skt,
              if (showDepo) 'depo',
              if (has(FeatureKeys.merchandising)) FeatureKeys.merchandising,
              if (has(FeatureKeys.forms)) FeatureKeys.forms,
              if (has(FeatureKeys.announcements)) FeatureKeys.announcements,
              if (has(FeatureKeys.tasks)) FeatureKeys.tasks,
              if (showRequests) FeatureKeys.requests,
              if (has(FeatureKeys.timeAttendance)) FeatureKeys.timeAttendance,
              if (has(FeatureKeys.shifts)) FeatureKeys.shifts,
              if (has(FeatureKeys.breakTracking)) FeatureKeys.breakTracking,
            ];

            List<String> normalized(List<String> list) {
              final out = <String>[];
              var insertedRequests = false;
              for (final k in list) {
                if (k == FeatureKeys.leaveRequest ||
                    k == FeatureKeys.itTicket) {
                  if (showRequests && !insertedRequests) {
                    out.add(FeatureKeys.requests);
                    insertedRequests = true;
                  }
                } else {
                  out.add(k);
                }
              }
              if (showRequests && !out.contains(FeatureKeys.requests)) {
                out.add(FeatureKeys.requests);
              }
              return out;
            }

            final baseOrder = normalized(_order);
            final order = <String>[
              ...baseOrder.where((k) => activeKeys.contains(k)),
              ...activeKeys.where((k) => !baseOrder.contains(k)),
            ];
            if (jsonEncode(order) != jsonEncode(_order)) {
              _order = order;
              _persistOrder();
            }
            final entries = _order.map(_entryFor).toList();

            return CustomBackButton(
              onBackPressed: _activePageKey != null
                  ? () => setState(() => _activePageKey = null)
                  : () async {
                      try {
                        if (_sheetCtrl.size > kMinSheetSize + 0.01) {
                          await _sheetCtrl.animateTo(
                            kMinSheetSize,
                            duration: const Duration(milliseconds: 140),
                            curve: Curves.easeOut,
                          );
                        } else {
                          await _handleLogout();
                        }
                      } catch (_) {
                        await _handleLogout();
                      }
                    },
              child: Scaffold(
                extendBody: true,
                body: Stack(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: _buildActivePage(),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: _BottomSheet(
                        controller: _sheetCtrl,
                        entries: entries,
                        displayName: '${user.name} ${user.surname}',
                        minSize: kMinSheetSize,
                        maxSize: kMaxSheetSize,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            final item = _order.removeAt(oldIndex);
                            _order.insert(newIndex, item);
                          });
                          _persistOrder();
                        },
                        onTap: (key) async {
                          try {
                            if (_sheetCtrl.size > kMinSheetSize + 0.01) {
                              await _sheetCtrl.animateTo(
                                kMinSheetSize,
                                duration: const Duration(milliseconds: 140),
                                curve: Curves.easeOut,
                              );
                            }
                          } catch (_) {}
                          _openFeature(key);
                        },
                        onProfileTap: () async {
                          try {
                            await _sheetCtrl.animateTo(
                              kMinSheetSize,
                              duration: const Duration(milliseconds: 140),
                              curve: Curves.easeOut,
                            );
                          } catch (_) {}
                          _openFeature(FeatureKeys.profile);
                        },
                        onSettingsTap: () async {
                          try {
                            if (_sheetCtrl.size > kMinSheetSize + 0.01) {
                              await _sheetCtrl.animateTo(
                                kMinSheetSize,
                                duration: const Duration(milliseconds: 140),
                                curve: Curves.easeOut,
                              );
                            }
                          } catch (_) {}
                          if (!mounted) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      unauthenticated: () => const LoginScreen(),
      loading: () => const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      ),
      initial: () => const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      ),
      error: (msg) => Scaffold(
        body: Center(child: Text('Hata: $msg')),
      ),
    );
  }

  Widget _buildActivePage() {
    final pageKey = _activePageKey;
    if (pageKey == null) {
      return const TitleScaffold(
        key: ValueKey('home'),
        title: 'Ana Sayfa',
      );
    }

    switch (pageKey) {
      case FeatureKeys.skt:
        return const SktListPage();
      case 'depo':
        return const TitleScaffold(
          key: ValueKey('depo'),
          title: 'Depo',
        );
      case FeatureKeys.merchandising:
        return const TitleScaffold(
          key: ValueKey('merch'),
          title: 'Mörş / Plasiyer',
        );
      case FeatureKeys.forms:
        return const TitleScaffold(
          key: ValueKey('forms'),
          title: 'Formlar',
        );
      case FeatureKeys.shifts:
        return const TitleScaffold(
          key: ValueKey('shifts'),
          title: 'Vardiya',
        );
      case FeatureKeys.announcements:
        return const TitleScaffold(
          key: ValueKey('ann'),
          title: 'Duyurular',
        );
      case FeatureKeys.tasks:
        return const TitleScaffold(
          key: ValueKey('tasks'),
          title: 'Görevler',
        );
      case FeatureKeys.requests:
        return const TitleScaffold(
          key: ValueKey('req'),
          title: 'Talepler',
        );
      case FeatureKeys.breakTracking:
        return const TitleScaffold(
          key: ValueKey('break'),
          title: 'Mola',
        );
      case FeatureKeys.timeAttendance:
        return const TitleScaffold(
          key: ValueKey('ta'),
          title: 'Mesai Giriş/Çıkış',
        );
      case FeatureKeys.profile:
        return const TitleScaffold(
          key: ValueKey('profile'),
          title: 'Profil',
        );
      default:
        return TitleScaffold(
          key: ValueKey<String>(pageKey),
          title: pageKey,
        );
    }
  }

  void _openFeature(String key) {
    setState(() => _activePageKey = key);
  }
}

class _BottomSheet extends StatefulWidget {
  const _BottomSheet({
    required this.controller,
    required this.entries,
    required this.displayName,
    required this.minSize,
    required this.maxSize,
    required this.onReorder,
    required this.onTap,
    required this.onProfileTap,
    required this.onSettingsTap,
  });

  final DraggableScrollableController controller;
  final List<FeatureEntry> entries;
  final String displayName;
  final double minSize;
  final double maxSize;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(String key) onTap;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;

  @override
  State<_BottomSheet> createState() => _BottomSheetState();
}

class _BottomSheetState extends State<_BottomSheet> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onSheetChanged);
  }

  void _onSheetChanged() {
    final expanded = widget.controller.size > (widget.minSize + 0.05);
    if (expanded != _isExpanded) {
      setState(() => _isExpanded = expanded);
    }
  }

  Future<void> _toggleSnap() async {
    final target = widget.controller.size < (widget.minSize + 0.02)
        ? widget.maxSize
        : widget.minSize;
    try {
      await widget.controller.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onSheetChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      controller: widget.controller,
      expand: false,
      initialChildSize: widget.minSize,
      minChildSize: widget.minSize,
      maxChildSize: widget.maxSize,
      snap: true,
      snapSizes: [widget.minSize, widget.maxSize],
      builder: (context, scrollCtrl) {
        return SafeArea(
          top: false,
          child: Material(
            elevation: 16,
            shadowColor: Colors.black.withOpacity(0.3),
            color: color.primaryContainer.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Column(
              children: [
                InkWell(
                  onTap: _toggleSnap,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: color.onPrimaryContainer.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    controller: scrollCtrl,
                    physics: const ClampingScrollPhysics(),
                    slivers: [
                      if (_isExpanded)
                        _ReorderableGridSliver(
                          entries: widget.entries,
                          onReorder: widget.onReorder,
                          onTap: widget.onTap,
                        )
                      else
                        _HorizontalIconList(
                          entries: widget.entries.take(5).toList(),
                          onTap: widget.onTap,
                        ),
                      if (_isExpanded)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Divider(
                                  color:
                                      color.onPrimaryContainer.withOpacity(0.2),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: color.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: color.outline.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      InkWell(
                                        onTap: widget.onProfileTap,
                                        borderRadius: BorderRadius.circular(8),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: color.primary,
                                              radius: 20,
                                              child: Icon(
                                                Icons.person,
                                                color: color.onPrimary,
                                                size: 22,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  widget.displayName.isEmpty
                                                      ? 'Kullanıcı'
                                                      : widget.displayName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15,
                                                    color: color.onSurface,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  'Profili Görüntüle',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        color.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        onPressed: widget.onSettingsTap,
                                        icon: Icon(
                                          Icons.settings,
                                          color: color.primary,
                                          size: 28,
                                        ),
                                        tooltip: 'Ayarlar',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HorizontalIconList extends StatelessWidget {
  const _HorizontalIconList({
    required this.entries,
    required this.onTap,
  });

  final List<FeatureEntry> entries;
  final void Function(String key) onTap;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 80,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final e = entries[i];
            return _CompactIcon(
              entry: e,
              onTap: () => onTap(e.key),
            );
          },
        ),
      ),
    );
  }
}

class _CompactIcon extends StatelessWidget {
  const _CompactIcon({
    required this.entry,
    required this.onTap,
  });

  final FeatureEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.outline.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(entry.icon, color: c.primary, size: 26),
              const SizedBox(height: 4),
              Text(
                entry.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReorderableGridSliver extends StatefulWidget {
  const _ReorderableGridSliver({
    required this.entries,
    required this.onReorder,
    required this.onTap,
  });

  final List<FeatureEntry> entries;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(String key) onTap;

  @override
  State<_ReorderableGridSliver> createState() => _ReorderableGridSliverState();
}

class _ReorderableGridSliverState extends State<_ReorderableGridSliver> {
  int? _dragIndex;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 420 ? 5 : 4;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          const gap = 12.0;
          final itemWidth =
              (constraints.crossAxisExtent - gap * (crossAxisCount - 1)) /
                  crossAxisCount;
          const itemHeight = 88.0;

          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              childAspectRatio: itemWidth / itemHeight,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final e = widget.entries[i];
                final isDragging = _dragIndex == i;

                return LongPressDraggable<int>(
                  data: i,
                  onDragStarted: () => setState(() => _dragIndex = i),
                  onDraggableCanceled: (_, __) =>
                      setState(() => _dragIndex = null),
                  onDragEnd: (_) => setState(() => _dragIndex = null),
                  feedback: _GridTile(
                    entry: e,
                    width: itemWidth,
                    height: itemHeight,
                    dragging: true,
                  ),
                  childWhenDragging: Opacity(
                    opacity: .25,
                    child: _GridTile(
                      entry: e,
                      width: itemWidth,
                      height: itemHeight,
                    ),
                  ),
                  child: DragTarget<int>(
                    onWillAccept: (from) => from != i,
                    onAccept: (from) {
                      widget.onReorder(from, i);
                      setState(() => _dragIndex = null);
                    },
                    builder: (context, _, __) => _GridTile(
                      entry: e,
                      width: itemWidth,
                      height: itemHeight,
                      dragging: isDragging,
                      onTap: () => widget.onTap(e.key),
                    ),
                  ),
                );
              },
              childCount: widget.entries.length,
            ),
          );
        },
      ),
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.entry,
    required this.width,
    required this.height,
    this.dragging = false,
    this.onTap,
  });

  final FeatureEntry entry;
  final double width;
  final double height;
  final bool dragging;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        elevation: dragging ? 6 : 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: c.outline.withOpacity(0.2),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(entry.icon, color: c.primary, size: 28),
                const SizedBox(height: 6),
                Text(
                  entry.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TitleScaffold extends StatelessWidget {
  const TitleScaffold({required this.title, super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const SizedBox.shrink(),
    );
  }
}
