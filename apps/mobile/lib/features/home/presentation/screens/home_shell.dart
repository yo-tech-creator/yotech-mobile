import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yotech_mobile/features/break_tracking/break_tracking.dart';
import 'package:yotech_mobile/features/skt/domain/models/skt_record_model.dart';
import 'package:yotech_mobile/features/skt/domain/providers/skt_providers.dart';
import 'package:yotech_mobile/features/skt/presentation/screens/skt_list_page.dart';
import 'package:yotech_mobile/core/features/feature_repo.dart';
import 'package:yotech_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:yotech_mobile/features/settings/presentation/screens/settings_page.dart';
import 'package:yotech_mobile/shared/widgets/custom_back_button.dart';
import 'package:yotech_mobile/features/auth/domain/providers/auth_provider.dart';
import 'package:yotech_mobile/features/inventory_transfer/presentation/providers/inventory_transfer_provider.dart';
import 'package:yotech_mobile/features/inventory_transfer/presentation/screens/inventory_transfer_list_screen.dart';
import 'package:yotech_mobile/features/merch/presentation/screens/merch_screen.dart';
import 'package:yotech_mobile/features/tasks/presentation/screens/branch_tasks_page.dart';
import 'package:yotech_mobile/features/requests/presentation/screens/requests_hub_page.dart';

class FeatureKeys {
  static const skt = 'skt';
  static const forms = 'forms';
  static const shifts = 'shifts';
  static const announcements = 'announcements';
  static const tasks = 'tasks';
  static const interbranchTransfer = 'interbranch_transfer';
  static const leaveRequest = 'leave_request';
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

const double kMinSheetSize = 0.12;

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
                              .clamp(kMinSheetSize + 0.05, 0.45)
                              .toDouble();
                          if (computedMax < kMinSheetSize + 0.05) {
                            computedMax = kMinSheetSize + 0.05;
                          }
                          final computedProfile = (desiredPixels / screenH)
                              .clamp(computedMax + 0.01, 0.60)
                              .toDouble();

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
                              _openFeature(FeatureKeys.profile);
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
      return const HomeDashboard(key: ValueKey('home'));
    }

    switch (pageKey) {
      case FeatureKeys.skt:
        return const SktListPage();
      case 'depo':
        return const InventoryTransferListScreen();
      case FeatureKeys.merchandising:
        return const MerchScreen();
      case FeatureKeys.forms:
        return const ModuleDemoPage(
          key: ValueKey('forms'),
          title: 'Form Yönetimi',
          tagline: 'Dinamik form düzenleme ve yanıt toplama',
          description:
              'Mağaza denetimlerinden kalite kontrol listelerine kadar her şey blok tabanlı form editörü ile hazırlanıyor.',
          icon: Icons.assignment,
          highlights: [
            DemoHighlight(
              title: 'Şablon Kütüphanesi',
              description:
                  'Hazır soru bloklarını sürükle-bırak ile yeniden kullanın, zorunlu alanlar anında işaretlenir.',
              icon: Icons.library_books,
            ),
            DemoHighlight(
              title: 'Onay Akışları',
              description:
                  'Form gönderildikten sonra bölge müdürü veya kalite ekibi aynı karttan inceleme yapar.',
              icon: Icons.verified,
            ),
            DemoHighlight(
              title: 'Offline Kayıt',
              description:
                  'Saha zayıf bağlantıdayken bile cevaplar saklanır, internet geldiğinde otomatik gönderilir.',
              icon: Icons.offline_bolt,
            ),
          ],
        );
      case FeatureKeys.shifts:
        return const ShiftsHubPage();
      case FeatureKeys.announcements:
        return const ModuleDemoPage(
          key: ValueKey('ann'),
          title: 'Duyurular',
          tagline: 'Firma içi yayın ve takip',
          description:
              'Genel merkez metin, görsel veya video duyurularını segment bazlı yayınlayıp okunma oranını izler.',
          icon: Icons.campaign,
          highlights: [
            DemoHighlight(
              title: 'Segment Bazlı Gönderim',
              description:
                  'Tenant, bölge veya rol seçerek yalnızca ilgili personele mesaj gönderin.',
              icon: Icons.segment,
            ),
            DemoHighlight(
              title: 'Okundu Takibi',
              description:
                  'Kimlerin duyuruyu açtığı gerçek zamanlı grafikte görünür.',
              icon: Icons.visibility,
            ),
            DemoHighlight(
              title: 'Zengin İçerik',
              description:
                  'PDF, video veya bağlantı ekleyip tek karttan paylaşın.',
              icon: Icons.attach_file,
            ),
          ],
        );
      case FeatureKeys.tasks:
        return const BranchTasksPage();
      case FeatureKeys.requests:
        return const RequestsHubPage();
      case FeatureKeys.timeAttendance:
        return const ModuleDemoPage(
          key: ValueKey('ta'),
          title: 'Puantaj',
          tagline: 'Giriş-çıkış ve mesai hesaplama',
          description:
              'Mobil cihazdan konum doğrulamalı giriş çıkış yapılır, bordro için onaylı puantaj listesi oluşur.',
          icon: Icons.fingerprint,
          highlights: [
            DemoHighlight(
              title: 'Mobil Check-in',
              description:
                  'Cihaz doğrulaması ve fotoğraf zorunluluğu ile sahte giriş engellenir.',
              icon: Icons.phonelink_lock,
            ),
            DemoHighlight(
              title: 'Konum Doğrulama',
              description:
                  'Şube sınırı dışındaki girişler otomatik işaretlenir.',
              icon: Icons.place,
            ),
            DemoHighlight(
              title: 'Muhasebe Aktarımı',
              description:
                  'Onaylı puantajı CSV/Excel olarak indirip dış sistemlere aktarın.',
              icon: Icons.receipt_long,
            ),
          ],
        );
      case FeatureKeys.profile:
        return const ModuleDemoPage(
          key: ValueKey('profile'),
          title: 'Profil ve Ayarlar',
          tagline: 'Kişisel bilgiler, cihaz izinleri ve bildirim tercihleri',
          description:
              'Kullanıcılar fotoğrafını, iletişim bilgilerini ve cihaz yetkilerini buradan düzenleyebilecek.',
          icon: Icons.person,
          highlights: [
            DemoHighlight(
              title: 'Yetki Görünümü',
              description:
                  'Kullanıcı hangi tenant ve şubeye bağlı olduğunu tek ekranda teyit eder.',
              icon: Icons.badge,
            ),
            DemoHighlight(
              title: 'Cihaz İzinleri',
              description:
                  'Kamera/konum gibi izinler açık mı kapalı mı hızlıca kontrol edilir.',
              icon: Icons.security,
            ),
            DemoHighlight(
              title: 'Bildirim Tercihleri',
              description:
                  'Sessiz saatler ve bildirim kanal tercihleri yönetilir.',
              icon: Icons.notifications,
            ),
          ],
        );
      default:
        return ModuleDemoPage(
          key: ValueKey<String>(pageKey),
          title: pageKey,
          tagline: 'Demo ekranı',
          description:
              'Bu özellik için henüz canlı veri yok. Tasarım ekibi bileşenleri hazırlar hazırlamaz buraya bağlanacak.',
          icon: Icons.explore,
          highlights: const [
            DemoHighlight(
              title: 'Kayıt Listesi',
              description:
                  'Örnek kayıtlar, filtreler ve detay ekranları burada gösterilecek.',
              icon: Icons.view_list,
            ),
            DemoHighlight(
              title: 'Analiz Kutuları',
              description:
                  'Grafikler ve KPI kartları ile hızlı özet yer alacak.',
              icon: Icons.analytics,
            ),
          ],
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
    final profileSnap = widget.profileSize ?? widget.maxSize;
    final showProfileFooter = size >= (profileSnap - 0.01);

    if (expanded != _isExpanded || showProfileFooter != _showProfileFooter) {
      setState(() {
        _isExpanded = expanded;
        _showProfileFooter = showProfileFooter;
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

    // Allow dragging straight to the profile snap so the footer can appear
    // on the first pull.
    final maxChild = widget.profileSize ?? widget.maxSize;
    final snapList = <double>[widget.minSize];
    final profileSnap = widget.profileSize ?? widget.maxSize;
    if ((profileSnap - widget.minSize).abs() > 0.001) {
      snapList.add(profileSnap);
    }

    var sheetDragActive = false;

    return DraggableScrollableSheet(
      controller: widget.controller,
      expand: false,
      initialChildSize: widget.minSize,
      minChildSize: widget.minSize,
      maxChildSize: maxChild,
      snap: true,
      snapSizes: snapList,
      builder: (context, scrollCtrl) {
        const double headerHeight = 15.0;
        final snapTargets = snapList;
        void handleDragUpdate(DragUpdateDetails details) {
          final screenH = MediaQuery.of(context).size.height;
          const deltaScale = 0.8;
          final dy = details.delta.dy;
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
        }

        Future<void> handleDragEnd(DragEndDetails details) async {
          final current = widget.controller.size;
          double closest = snapTargets.first;
          for (final s in snapTargets) {
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
          } catch (_) {}
        }

        bool canScrollSheetDown(DragUpdateDetails details) {
          final pullingDown = details.delta.dy > 0;
          final atTop =
              !scrollCtrl.hasClients || scrollCtrl.position.pixels <= 0;
          // Allow pulling sheet when collapsed or when expanded content is at
          // top and user drags downward.
          return !_isExpanded || (pullingDown && atTop);
        }

        void handleContentDragUpdate(DragUpdateDetails details) {
          if (!canScrollSheetDown(details)) return;
          sheetDragActive = true;
          handleDragUpdate(details);
        }

        Future<void> handleContentDragEnd(DragEndDetails details) async {
          if (!sheetDragActive) return;
          sheetDragActive = false;
          await handleDragEnd(details);
        }

        return SafeArea(
          top: false,
          child: Material(
            elevation: 16,
            shadowColor: Colors.black.withAlpha((0.3 * 255).round()),
            color: color.primaryContainer.withAlpha((0.95 * 255).round()),
            clipBehavior: Clip.antiAlias,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragUpdate: handleDragUpdate,
                  onVerticalDragEnd: handleDragEnd,
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
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragUpdate: handleContentDragUpdate,
                    onVerticalDragEnd: handleContentDragEnd,
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
                            onVerticalDragUpdate: handleContentDragUpdate,
                            onVerticalDragEnd: handleContentDragEnd,
                          ),
                        // Profile/footer area is shown once the sheet reaches
                        // the full snap (profileSnap). Visibility is tracked by
                        // _showProfileFooter.
                        // profile/footer removed from slivers to prevent inner
                        // scrolling from revealing it. The footer will be
                        // rendered below the scroll area as a sibling widget.
                      ],
                    ),
                  ),
                ),
                // Render the profile/footer area as a sibling below the
                // scroll area. It should not be part of the scrollable
                // slivers so inner content scrolling cannot reveal it.
                if (widget.profileSize != null)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _showProfileFooter
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: double.infinity,
                                height: 1,
                                color: color.onPrimaryContainer
                                    .withAlpha((0.1 * 255).round()),
                              ),
                              Container(
                                // Provide enough height for the profile row and
                                // include bottom safe area padding so the footer
                                // sits above system UI.
                                height: 64 +
                                    MediaQuery.of(context).viewPadding.bottom,
                                padding: EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  bottom:
                                      MediaQuery.of(context).viewPadding.bottom,
                                ),
                                child: Material(
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
                                            backgroundColor:
                                                color.primaryContainer,
                                            child: Icon(
                                              Icons.person,
                                              color: color.onPrimaryContainer,
                                            ),
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
                                            icon: Icon(
                                              Icons.settings,
                                              color: color.onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
  });

  final List<FeatureEntry> entries;
  final void Function(String key) onTap;
  final void Function(DragUpdateDetails details)? onVerticalDragUpdate;
  final void Function(DragEndDetails details)? onVerticalDragEnd;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragUpdate: onVerticalDragUpdate,
        onVerticalDragEnd: onVerticalDragEnd,
        child: SizedBox(
          height: 72,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const itemWidth = 84.0;
              const spacing = 8.0;
              const padding = 32.0; // 16 px left + 16 px right
              final totalWidth = entries.isEmpty
                  ? 0
                  : (entries.length * itemWidth) +
                      ((entries.length - 1) * spacing) +
                      padding;
              final fitsWithoutScroll = totalWidth <= constraints.maxWidth;

              if (fitsWithoutScroll) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                  child: Align(
                    alignment: Alignment.center,
                    child: Wrap(
                      spacing: spacing,
                      children: entries
                          .map(
                            (e) => SizedBox(
                              width: itemWidth,
                              child: _CompactFlexible(
                                entry: e,
                                onTap: () => onTap(e.key),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                );
              }

              return ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(width: spacing),
                itemBuilder: (context, i) {
                  final e = entries[i];
                  return SizedBox(
                    width: itemWidth,
                    child:
                        _CompactFlexible(entry: e, onTap: () => onTap(e.key)),
                  );
                },
              );
            },
          ),
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
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(entry.icon, color: c.primary, size: 22),
            const SizedBox(height: 4),
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

class HomeDashboard extends ConsumerWidget {
  const HomeDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(sktRecordsProvider);

    Future<void> handleRefresh() async {
      ref.invalidate(sktRecordsProvider);
      await ref.read(sktRecordsProvider.future);
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ana Sayfa')),
      body: RefreshIndicator(
        onRefresh: handleRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Hızlı Bakış',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            BreakQuickActionCard(
              onViewHistory: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ShiftsHubPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            SktAlertSection(recordsAsync: recordsAsync),
            const SizedBox(height: 20),
            const _AnnouncementsPlaceholder(),
            const SizedBox(height: 12),
            const InventoryQuickNotificationsCard(),
            const SizedBox(height: 24),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

class SktAlertSection extends StatelessWidget {
  const SktAlertSection({required this.recordsAsync, super.key});

  final AsyncValue<List<SktRecordModel>> recordsAsync;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'SKT Takip Alanı',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SktListPage(),
                      ),
                    );
                  },
                  child: const Text('Tümünü Gör'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            recordsAsync.when(
              data: (records) => _buildRecordBody(context, records),
              loading: () => const SizedBox(
                height: 64,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, _) => Text(
                'SKT kayıtları yüklenemedi\n${err.toString()}',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: card,
    );
  }

  Widget _buildRecordBody(BuildContext context, List<SktRecordModel> records) {
    final now = DateTime.now();
    final alerts = records.where((record) {
      final semanticStatus = record.status?.toLowerCase();
      if (semanticStatus == 'gecmis' || semanticStatus == 'yaklasan') {
        return true;
      }
      final computedStatus = record.statusAt(now);
      return computedStatus != SktRecordStatus.normal;
    }).toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    if (alerts.isEmpty) {
      return const Text(
        'Takip gerektiren ürün bulunmuyor. SKT stokları güncel görünüyor.',
      );
    }

    final preview = alerts.take(8).toList();

    return SizedBox(
      height: 248,
      child: ScrollConfiguration(
        behavior: const _TonedDownScrollBehavior(),
        child: ListView.separated(
          itemCount: preview.length,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) =>
              _SktAlertTile(record: preview[index]),
          separatorBuilder: (_, __) =>
              const Divider(height: 16, thickness: 0.4),
        ),
      ),
    );
  }
}

class _SktAlertTile extends StatelessWidget {
  const _SktAlertTile({required this.record});

  final SktRecordModel record;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysLeft = record.daysUntil(now);
    final colorScheme = Theme.of(context).colorScheme;
    final pill = _buildStatusPill(colorScheme, daysLeft);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        record.productName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${record.branchName} · SKT ${_formatDate(record.expiryDate)}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          pill,
          const SizedBox(height: 6),
          Text(
            '${record.quantity} adet',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(ColorScheme colors, int daysLeft) {
    late final String label;
    late final Color bg;
    late final Color fg;

    if (daysLeft < 0) {
      label = 'SKT geçti';
      bg = colors.errorContainer;
      fg = colors.onErrorContainer;
    } else if (daysLeft == 0) {
      label = 'Bugün son gün';
      bg = colors.tertiaryContainer;
      fg = colors.onTertiaryContainer;
    } else {
      label = '$daysLeft günde tüket';
      bg = colors.secondaryContainer;
      fg = colors.onSecondaryContainer;
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AnnouncementsPlaceholder extends StatelessWidget {
  const _AnnouncementsPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Duyurular',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.campaign_outlined,
                      color: theme.colorScheme.primary),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Bu alanı kurum içi duyurular ve mağaza odaklı haberler için kullanacağız. İçerik hazır olduğunda otomatik olarak listelenecek.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InventoryQuickNotificationsCard extends ConsumerWidget {
  const InventoryQuickNotificationsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indicators = ref.watch(inventoryTransferIndicatorsProvider);
    final notifications = indicators.quickNotifications;
    if (notifications.isEmpty) {
      return const _QuickNotificationsPlaceholder();
    }

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hızlı Bildirimler',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.notifications, color: theme.colorScheme.primary),
                ],
              ),
              const SizedBox(height: 12),
              ...notifications.asMap().entries.map((entry) {
                final notification = entry.value;
                final isLast = entry.key == notifications.length - 1;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                  child: _QuickNotificationTile(
                    notification: notification,
                    onTap: () => _handleNotificationTap(
                      context,
                      ref,
                      notification,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleNotificationTap(
    BuildContext context,
    WidgetRef ref,
    InventoryTransferQuickNotification notification,
  ) async {
    final user = ref.read(authProvider).mapOrNull(authenticated: (s) => s.user);
    final userId = user?.id;
    if (userId != null) {
      ref
          .read(inventoryTransferAlertStatusProvider(userId).notifier)
          .markNotificationSeen(notification.createdAt);
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InventoryTransferListScreen(
          initialTabIndex: notification.targetTabIndex,
        ),
      ),
    );
  }
}

class _QuickNotificationTile extends StatelessWidget {
  const _QuickNotificationTile({
    required this.notification,
    this.onTap,
  });

  final InventoryTransferQuickNotification notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visuals = _NotificationVisuals.resolve(notification.type, colors);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: visuals.background,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(8),
            child: Icon(
              visuals.icon,
              color: visuals.iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(notification.description),
                const SizedBox(height: 4),
                Text(
                  _formatRelativeTime(notification.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationVisuals {
  const _NotificationVisuals({
    required this.icon,
    required this.background,
    required this.iconColor,
  });

  final IconData icon;
  final Color background;
  final Color iconColor;

  static _NotificationVisuals resolve(
    InventoryTransferNotificationType type,
    ColorScheme colors,
  ) {
    switch (type) {
      case InventoryTransferNotificationType.incomingOffer:
        return _NotificationVisuals(
          icon: Icons.mark_email_unread,
          background: colors.primaryContainer,
          iconColor: colors.primary,
        );
      case InventoryTransferNotificationType.offerAccepted:
        return _NotificationVisuals(
          icon: Icons.check_circle,
          background: colors.secondaryContainer,
          iconColor: colors.secondary,
        );
      case InventoryTransferNotificationType.offerRejected:
        return _NotificationVisuals(
          icon: Icons.cancel,
          background: colors.errorContainer,
          iconColor: colors.error,
        );
      case InventoryTransferNotificationType.offerCancelled:
        return _NotificationVisuals(
          icon: Icons.undo,
          background: colors.surfaceContainerHighest,
          iconColor: colors.tertiary,
        );
      case InventoryTransferNotificationType.shortageNotice:
        return _NotificationVisuals(
          icon: Icons.trending_down,
          background: colors.tertiaryContainer,
          iconColor: colors.tertiary,
        );
      case InventoryTransferNotificationType.surplusNotice:
        return _NotificationVisuals(
          icon: Icons.trending_up,
          background: colors.surfaceContainerHighest,
          iconColor: colors.primary,
        );
    }
  }
}

String _formatRelativeTime(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Az önce';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
  if (diff.inHours < 24) return '${diff.inHours} sa önce';
  return '${diff.inDays} gün önce';
}

class _QuickNotificationsPlaceholder extends StatelessWidget {
  const _QuickNotificationsPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Hızlı Bildirimler',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.notifications_none,
                      color: theme.colorScheme.primary),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Görev hatırlatmaları, mini uyarılar ve mağaza içi aksiyonlar burada listelenecek. Entegrasyonlar tamamlandığında otomatik doldurulacak.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TonedDownScrollBehavior extends ScrollBehavior {
  const _TonedDownScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

class DemoHighlight {
  const DemoHighlight({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

class ModuleDemoPage extends StatelessWidget {
  const ModuleDemoPage({
    required this.title,
    required this.tagline,
    required this.description,
    required this.icon,
    this.highlights = const <DemoHighlight>[],
    this.note,
    super.key,
  });

  final String title;
  final String tagline;
  final String description;
  final IconData icon;
  final List<DemoHighlight> highlights;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final infoText = note ??
        'Bu ekran demo verisi ile hazırlanmıştır. Modül canlıya alındığında gerçek kayıtlar burada görünecek.';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.12),
                    child:
                        Icon(icon, size: 32, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tagline,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          if (highlights.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Demo senaryoları',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...highlights.map((h) => _DemoHighlightTile(highlight: h)),
          ],
          const SizedBox(height: 18),
          _InfoNote(text: infoText),
        ],
      ),
    );
  }
}

class _DemoHighlightTile extends StatelessWidget {
  const _DemoHighlightTile({required this.highlight});

  final DemoHighlight highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.12),
          child: Icon(highlight.icon, color: theme.colorScheme.secondary),
        ),
        title: Text(
          highlight.title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(highlight.description),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
