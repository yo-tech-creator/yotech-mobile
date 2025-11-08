import 'dart:convert';
import 'dart:developer' as developer;
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
  const HomeShell({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

const double kMinSheetSize = 0.18;

class _HomeShellState extends ConsumerState<HomeShell> {
  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();
  List<String> _order = <String>[];
  String? _activePageKey;

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      });
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
                      child: Builder(
                        builder: (context) {
                          final screenH = MediaQuery.of(context).size.height;
                          final screenW = MediaQuery.of(context).size.width;
                          final crossAxisCount = screenW > 420 ? 5 : 4;
                          final rows = ((entries.length + crossAxisCount - 1) ~/
                                  crossAxisCount)
                              .clamp(1, 10);
                          const headerHeight = 56.0;
                          const itemHeight = 88.0;
                          // height reserved for the profile row area
                          const profileAreaHeight = 64.0;
                          // minimal extra padding so profile sits near screen bottom
                          const otherPadding = 8.0;
                          final desiredPixels = headerHeight +
                              rows * itemHeight +
                              profileAreaHeight +
                              otherPadding;
                          // Limit how tall the sheet can grow on small devices.
                          // Keep feature-area visible but ensure profile snap is a
                          // small additional increment above it.
                          var computedMax = (desiredPixels / screenH)
                              .clamp(kMinSheetSize + 0.05, 0.45);
                          if (computedMax < kMinSheetSize + 0.05) {
                            computedMax = kMinSheetSize + 0.05;
                          }
                          final computedProfile = (desiredPixels / screenH)
                              .clamp(computedMax + 0.01, 0.60);

                          return _BottomSheet(
                            controller: _sheetCtrl,
                            entries: entries,
                            displayName: '${user.name} ${user.surname}',
                            minSize: kMinSheetSize,
                            maxSize: computedMax,
                            profileSize: computedProfile,
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
                                final navigator = Navigator.of(context);
                                if (_sheetCtrl.size > kMinSheetSize + 0.01) {
                                  await _sheetCtrl.animateTo(
                                    kMinSheetSize,
                                    duration: const Duration(milliseconds: 140),
                                    curve: Curves.easeOut,
                                  );
                                }
                                if (!mounted) return;
                                await navigator.push(
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsPage(),
                                  ),
                                );
                              } catch (_) {}
                            },
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
    this.profileSize,
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
  final double? profileSize;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(String key) onTap;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;

  @override
  State<_BottomSheet> createState() => _BottomSheetState();
}

class _BottomSheetState extends State<_BottomSheet> {
  bool _isExpanded = false;
  bool _showProfileFooter = false;
  // Becomes true when the user starts dragging the header handle. Used to
  // ensure the profile/footer area is only revealed by a handle pull and not
  // by inner content scrolling.
  bool _headerDragStarted = false;
  // Records whether the sheet was already expanded when the header drag
  // started. We only reveal the profile/footer when the user pulls the
  // header while already on the expanded features snap (i.e. a second
  // pull).
  bool _wasExpandedAtDragStart = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onSheetChanged);
  }

  void _onSheetChanged() {
    final size = widget.controller.size;
    developer.log('BottomSheet size changed: $size', name: 'home_shell');
    // Raise expanded threshold slightly so the closed state reliably
    // shows the horizontal strip (avoids tiny size deltas flipping to
    // expanded view).
    final expanded = size > (widget.minSize + 0.08);
    // We intentionally do NOT set `_showProfileFooter` to true here. The
    // profile/footer should only be revealed when the user explicitly pulls
    // the header handle a second time (handled in the header's
    // onVerticalDragEnd). However, if the sheet collapses below the hide
    // threshold, we must hide the footer immediately.
    var shouldHideFooter = false;
    if (widget.profileSize != null) {
      final hideThreshold = (widget.maxSize + widget.profileSize!) / 2;
      if (size < hideThreshold && _showProfileFooter) {
        shouldHideFooter = true;
      }
    }

    if (expanded != _isExpanded || shouldHideFooter) {
      setState(() {
        _isExpanded = expanded;
        if (shouldHideFooter) _showProfileFooter = false;
      });
    }
  }

  // _toggleSnap removed — not used. Keep method removed to silence unused warnings.

  @override
  void dispose() {
    widget.controller.removeListener(_onSheetChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;

    // Only allow the profile snap option once the sheet has reached the
    // expanded features state. This prevents jumping straight from the
    // collapsed state into the profile area and enforces the "second
    // pull" behaviour.
    final maxChild = (_isExpanded && widget.profileSize != null)
        ? widget.profileSize!
        : widget.maxSize;
    final snapList = <double>[widget.minSize, widget.maxSize];
    if (widget.profileSize != null &&
        _isExpanded &&
        widget.profileSize! > widget.maxSize) {
      snapList.add(widget.profileSize!);
    }

    return DraggableScrollableSheet(
      controller: widget.controller,
      expand: false,
      initialChildSize: widget.minSize,
      minChildSize: widget.minSize,
      maxChildSize: maxChild,
      snap: true,
      snapSizes: snapList,
      builder: (context, scrollCtrl) {
        const double headerHeight = 56.0;
        return SafeArea(
          top: false,
          child: Material(
            elevation: 16,
            shadowColor: Colors.black.withAlpha((0.3 * 255).round()),
            color: color.primaryContainer.withAlpha((0.95 * 255).round()),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (_) {
                    // Mark that a header drag began. Capture whether the
                    // sheet was already in the expanded state when the drag
                    // started — we only want a second pull (from expanded)
                    // to reveal the profile/footer.
                    _headerDragStarted = true;
                    _wasExpandedAtDragStart = _isExpanded;
                    developer.log(
                        'header drag started expanded=$_wasExpandedAtDragStart',
                        name: 'home_shell');
                  },
                  onVerticalDragUpdate: (details) {
                    final screenH = MediaQuery.of(context).size.height;
                    final dy = details.delta.dy;
                    // Use a larger scale so sheet moves responsively again.
                    const deltaScale = 0.8;
                    final deltaFraction = -dy / screenH * deltaScale;
                    final newSize = (widget.controller.size + deltaFraction)
                        .clamp(widget.minSize, maxChild);
                    developer.log(
                      'drag update dy=$dy cur=${widget.controller.size} new=$newSize',
                      name: 'home_shell.drag',
                    );
                    try {
                      widget.controller.jumpTo(newSize);
                    } catch (_) {}
                  },
                  onVerticalDragEnd: (details) async {
                    final current = widget.controller.size;
                    // Use the same snap sizes configured for the sheet so we
                    // pick the correct target (min, features max, optional
                    // profile snap).
                    final snapList = <double>[widget.minSize, widget.maxSize];
                    if (widget.profileSize != null) {
                      snapList.add(widget.profileSize!);
                    }
                    double closest = snapList.first;
                    for (final s in snapList) {
                      if ((s - current).abs() < (closest - current).abs()) {
                        closest = s;
                      }
                    }
                    developer.log(
                      'drag end velocity=${details.velocity.pixelsPerSecond.dy} current=$current target=$closest',
                      name: 'home_shell.drag',
                    );
                    try {
                      await widget.controller.animateTo(
                        closest,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                      );

                      // Only reveal the profile/footer if we landed on the
                      // profile snap AND the drag began from the header while
                      // already expanded (this enforces the "second pull"
                      // behaviour).
                      if (widget.profileSize != null &&
                          (closest - widget.profileSize!).abs() < 0.001 &&
                          _headerDragStarted &&
                          _wasExpandedAtDragStart) {
                        setState(() => _showProfileFooter = true);
                      } else if (_showProfileFooter) {
                        // If we didn't land on the profile snap, hide the
                        // footer.
                        setState(() => _showProfileFooter = false);
                      }
                    } catch (_) {
                      // ignore animation errors
                    } finally {
                      // Reset the header drag flag regardless of outcome so
                      // inner scrolling cannot reuse it.
                      _headerDragStarted = false;
                      _wasExpandedAtDragStart = false;
                    }
                  },
                  child: SizedBox(
                    width: double.infinity,
                    height: headerHeight,
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: color.onPrimaryContainer
                              .withAlpha((0.4 * 255).round()),
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
                        // When collapsed, show the full list in a horizontally
                        // scrolling strip so users can access all shortcuts.
                        _HorizontalIconList(
                          entries: widget.entries,
                          onTap: widget.onTap,
                        ),
                      // Profile/footer area is shown only when the sheet is
                      // dragged to the profile snap (second snap). Use
                      // _showProfileFooter which is updated by controller
                      // listener.
                      // profile/footer removed from slivers to prevent inner
                      // scrolling from revealing it. The footer will be
                      // rendered below the scroll area as a sibling widget.
                    ],
                  ),
                ),
                // Render the profile/footer area as a sibling below the
                // scroll area. It should not be part of the scrollable
                // slivers so inner content scrolling cannot reveal it.
                if (widget.profileSize != null)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _showProfileFooter
                        ? Container(
                            // Provide enough height for the profile row and
                            // include bottom safe area padding so the footer
                            // sits above system UI.
                            height:
                                64 + MediaQuery.of(context).viewPadding.bottom,
                            padding: EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: MediaQuery.of(context).viewPadding.bottom,
                            ),
                            child: Material(
                              // Keep the footer visually attached to the
                              // parent sheet by using a transparent material
                              // (parent already supplies the background and
                              // rounded corners) and no elevation.
                              color: Colors.transparent,
                              elevation: 0,
                              child: InkWell(
                                onTap: widget.onProfileTap,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: color.primaryContainer,
                                        child: Icon(Icons.person,
                                            color: color.onPrimaryContainer),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          widget.displayName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: color.onSurface,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: widget.onSettingsTap,
                                        icon: Icon(Icons.settings,
                                            color: color.onSurface),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
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
        height: 86,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final e = entries[i];
            return SizedBox(
              width: 88,
              child: _CompactFlexible(entry: e, onTap: () => onTap(e.key)),
            );
          },
        ),
      ),
    );
  }
}

// kept for compatibility if used elsewhere; prefer _CompactFlexible for horizontal strip
// _CompactIcon removed — use _CompactFlexible for the collapsed horizontal strip.

class _CompactFlexible extends StatelessWidget {
  const _CompactFlexible({required this.entry, required this.onTap});

  final FeatureEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(entry.icon, color: c.primary, size: 24),
            const SizedBox(height: 6),
            Text(
              entry.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: c.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
                    onWillAcceptWithDetails: (details) => details.data != i,
                    onAcceptWithDetails: (details) {
                      final from = details.data;
                      widget.onReorder(from, i);
                      setState(() => _dragIndex = null);
                    },
                    builder: (context, candidateData, rejectedData) {
                      final willAccept = candidateData.isNotEmpty;
                      return _GridTile(
                        entry: e,
                        width: itemWidth,
                        height: itemHeight,
                        dragging: isDragging,
                        highlight: willAccept,
                        onTap: () => widget.onTap(e.key),
                      );
                    },
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
    this.highlight = false,
    this.onTap,
  });

  final FeatureEntry entry;
  final double width;
  final double height;
  final bool dragging;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: highlight ? c.primaryContainer : c.surface,
        borderRadius: BorderRadius.circular(12),
        elevation: dragging || highlight ? 6 : 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: highlight
                    ? c.primary
                    : c.outline.withAlpha((0.2 * 255).round()),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(entry.icon, color: c.primary, size: 26),
                const SizedBox(height: 6),
                Text(
                  entry.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
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
