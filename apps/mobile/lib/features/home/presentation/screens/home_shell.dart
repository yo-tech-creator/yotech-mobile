import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:yotech_mobile/core/auth/auth_navigation_helper.dart';
import 'package:yotech_mobile/features/break_tracking/break_tracking.dart';
import 'package:yotech_mobile/features/skt/domain/models/skt_record_model.dart';
import 'package:yotech_mobile/features/skt/domain/providers/skt_providers.dart';
import 'package:yotech_mobile/features/skt/presentation/screens/skt_list_page.dart';
import 'package:yotech_mobile/core/features/feature_repo.dart';
import 'package:yotech_mobile/features/settings/presentation/screens/profile_page.dart';
import 'package:yotech_mobile/shared/widgets/custom_back_button.dart';
import 'package:yotech_mobile/features/auth/domain/providers/auth_provider.dart';
import 'package:yotech_mobile/features/inventory_transfer/presentation/providers/inventory_transfer_provider.dart';
import 'package:yotech_mobile/features/inventory_transfer/presentation/screens/inventory_transfer_list_screen.dart';
import 'package:yotech_mobile/features/merch/presentation/screens/merch_screen.dart';
import 'package:yotech_mobile/features/tasks/presentation/screens/branch_tasks_page.dart';
import 'package:yotech_mobile/features/requests/presentation/screens/requests_hub_page.dart';
import 'package:yotech_mobile/features/forms/presentation/screens/forms_hub_page.dart';
import 'package:yotech_mobile/features/announcements/presentation/screens/announcements_page.dart';
import 'package:yotech_mobile/features/visual_audit/visual_audit.dart';

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
  static const visualAudit = 'visual_audit';
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
    case FeatureKeys.visualAudit:
      return FeatureEntry(key, 'Görsel Denetim', Icons.camera_alt_rounded);
    default:
      return FeatureEntry(key, key, Icons.extension);
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

const double kMinSheetSize = 0.15;

class _HomeShellState extends ConsumerState<HomeShell> {
  final DraggableScrollableController _sheetCtrl =
      DraggableScrollableController();
  List<String> _order = <String>[];
  String? _activePageKey;
  String? _tenantName;

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
      // Post frame callback içinde yükle - ref hazır olur
      _loadShortcutOrder();
      _loadTenantName();
    });
  }

  Future<void> _loadTenantName() async {
    final authState = ref.read(authProvider);
    await authState.whenOrNull(
      authenticated: (user) async {
        try {
          // get_personal_profile RPC'si tenant_name döndürüyor
          final response = await Supabase.instance.client.rpc(
              'get_personal_profile',
              params: {'p_user_id': user.id}).maybeSingle();
          debugPrint(
              'Profile response tenant_name: ${response?['tenant_name']}');
          if (response != null && mounted) {
            setState(() {
              _tenantName = response['tenant_name'] as String?;
            });
          }
        } catch (e) {
          debugPrint('Tenant name yüklenemedi: $e');
        }
      },
    );
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
    await AuthNavigationHelper.confirmAndLogout(context: context, ref: ref);
  }

  String _getActivePageTitle() {
    switch (_activePageKey) {
      case FeatureKeys.skt:
        return 'SKT Takibi';
      case 'depo':
        return 'Depolar Arası Sevk';
      case FeatureKeys.merchandising:
        return 'Merchandising';
      case FeatureKeys.forms:
        return 'Formlar';
      case FeatureKeys.shifts:
        return 'Vardiya';
      case FeatureKeys.announcements:
        return 'Duyurular';
      case FeatureKeys.tasks:
        return 'Görevler';
      case FeatureKeys.requests:
        return 'Talepler';
      case FeatureKeys.timeAttendance:
        return 'Puantaj';
      case FeatureKeys.visualAudit:
        return 'Görsel Denetim';
      default:
        return 'Ana Sayfa';
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
              if (has(FeatureKeys.visualAudit)) FeatureKeys.visualAudit,
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
                appBar: AppBar(
                  titleSpacing: 16,
                  title: Row(
                    children: [
                      // Sol: Firma adı - tıklanınca ana sayfaya git
                      GestureDetector(
                        onTap: () {
                          if (_activePageKey != null) {
                            setState(() => _activePageKey = null);
                          }
                        },
                        child: Text(
                          _tenantName ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _activePageKey != null
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Orta: Sayfa adı badge
                      Expanded(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withAlpha(180),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _getActivePageTitle(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    // Profil butonu
                    IconButton(
                      icon: Icon(
                        Icons.account_circle,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      tooltip: 'Profil ve Ayarlar',
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            builder: (_) => const ProfilePage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                body: Stack(
                  children: [
                    // Ana içeriğe alt bar yüksekliği kadar padding ekle
                    Positioned.fill(
                      bottom: (MediaQuery.of(context).size.height *
                              kMinSheetSize) -
                          MediaQuery.of(context)
                              .viewPadding
                              .bottom, // Alt bar'ın kapalı yüksekliği (sistem padding çıkarılmış)
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: _buildActivePage(),
                      ),
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
                          const otherPadding = 16.0;
                          final desiredPixels =
                              headerHeight + rows * itemHeight + otherPadding;
                          // Limit how tall the sheet can grow on small devices.
                          var computedMax = (desiredPixels / screenH)
                              .clamp(kMinSheetSize + 0.05, 0.45)
                              .toDouble();
                          if (computedMax < kMinSheetSize + 0.05) {
                            computedMax = kMinSheetSize + 0.05;
                          }

                          return _BottomSheet(
                            controller: _sheetCtrl,
                            entries: entries,
                            minSize: kMinSheetSize,
                            maxSize: computedMax,
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                final item = _order.removeAt(oldIndex);
                                _order.insert(newIndex, item);
                              });
                              _persistOrder();
                            },
                            onTap: (key) {
                              // Önce sayfayı aç
                              _openFeature(key);

                              // Bar'ı animasyonsuz direkt kapat
                              if (_sheetCtrl.size > kMinSheetSize + 0.01) {
                                try {
                                  _sheetCtrl.jumpTo(kMinSheetSize);
                                } catch (_) {
                                  // Controller disposed olabilir
                                }
                              }
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
      // AuthWrapper zaten unauthenticated durumunu handle ediyor,
      // burada sadece loading göster - LoginScreen GÖSTERME!
      unauthenticated: () => const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      ),
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
        return const FormsHubPage();
      case FeatureKeys.shifts:
        return const ShiftsHubPage();
      case FeatureKeys.announcements:
        return const AnnouncementsPage();
      case FeatureKeys.tasks:
        return const BranchTasksPage();
      case FeatureKeys.requests:
        return const RequestsHubPage();
      case FeatureKeys.visualAudit:
        return const VisualAuditPage();
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
    required this.minSize,
    required this.maxSize,
    required this.onReorder,
    required this.onTap,
  });

  final DraggableScrollableController controller;
  final List<FeatureEntry> entries;
  final double minSize;
  final double maxSize;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(String key) onTap;

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
    final size = widget.controller.size;
    // Raise expanded threshold slightly so the closed state reliably
    // shows the horizontal strip (avoids tiny size deltas flipping to
    // expanded view).
    final expanded = size > (widget.minSize + 0.08);

    if (expanded != _isExpanded) {
      setState(() {
        _isExpanded = expanded;
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

    // Tek snap noktası: minSize ve maxSize
    final snapList = <double>[widget.minSize, widget.maxSize];

    var sheetDragActive = false;

    return DraggableScrollableSheet(
      controller: widget.controller,
      expand: false,
      initialChildSize: widget.minSize,
      minChildSize: widget.minSize,
      maxChildSize: widget.maxSize,
      snap: true,
      snapSizes: snapList,
      builder: (context, scrollCtrl) {
        void handleDragUpdate(DragUpdateDetails details) {
          final screenH = MediaQuery.of(context).size.height;
          const deltaScale = 0.8;
          final dy = details.delta.dy;
          final deltaFraction = -dy / screenH * deltaScale;
          final newSize = (widget.controller.size + deltaFraction)
              .clamp(widget.minSize, widget.maxSize);
          try {
            widget.controller.jumpTo(newSize);
          } catch (_) {}
        }

        Future<void> handleDragEnd(DragEndDetails details) async {
          final current = widget.controller.size;
          final velocity = details.velocity.pixelsPerSecond.dy;

          // Velocity threshold - hızlı kaydırmada yöne göre snap yap
          const velocityThreshold = 200.0;

          // Layout geçiş threshold'u ile aynı: minSize + 0.08
          final expandThreshold = widget.minSize + 0.08;

          double target;
          if (velocity > velocityThreshold) {
            // Aşağı hızlı kaydırma - kapat
            target = widget.minSize;
          } else if (velocity < -velocityThreshold) {
            // Yukarı hızlı kaydırma - aç
            target = widget.maxSize;
          } else {
            // Yavaş kaydırma - threshold'a göre karar ver
            // Layout geçişiyle uyumlu olması için aynı threshold kullan
            if (current > expandThreshold) {
              target = widget.maxSize;
            } else {
              target = widget.minSize;
            }
          }

          try {
            await widget.controller.animateTo(
              target,
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

        // viewPadding.bottom değerini bir kere al
        final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

        return Material(
          elevation: 16,
          shadowColor: Colors.black.withAlpha((0.3 * 255).round()),
          color: color.primaryContainer.withAlpha((0.95 * 255).round()),
          clipBehavior: Clip.antiAlias,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            children: [
              // Sürükleme tutamacı - kompakt
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragUpdate: handleDragUpdate,
                onVerticalDragEnd: handleDragEnd,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: color.onPrimaryContainer
                            .withAlpha((0.4 * 255).round()),
                        borderRadius: BorderRadius.circular(2),
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
                    physics: _isExpanded
                        ? const ClampingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
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
                    ],
                  ),
                ),
              ),
              // Alt sistem UI için boşluk - ekstra padding ekle
              SizedBox(height: bottomPadding + 4),
            ],
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
          height: 58,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const itemWidth = 72.0;
              const spacing = 6.0;
              const padding = 24.0; // 12 px left + 12 px right
              final totalWidth = entries.isEmpty
                  ? 0
                  : (entries.length * itemWidth) +
                      ((entries.length - 1) * spacing) +
                      padding;
              final fitsWithoutScroll = totalWidth <= constraints.maxWidth;

              if (fitsWithoutScroll) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
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
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
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
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 6),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(entry.icon, color: c.primary, size: 18),
            const SizedBox(height: 2),
            Text(
              entry.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
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

class HomeDashboard extends ConsumerStatefulWidget {
  const HomeDashboard({super.key});

  @override
  ConsumerState<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends ConsumerState<HomeDashboard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authState = ref.watch(authProvider);
    final recordsAsync = ref.watch(sktRecordsProvider);

    final user = authState.maybeWhen(
      authenticated: (u) => u,
      orElse: () => null,
    );

    Future<void> handleRefresh() async {
      ref.invalidate(sktRecordsProvider);
      await ref.read(sktRecordsProvider.future);
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: handleRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Hoş geldin başlık
            SliverToBoxAdapter(
              child: _WelcomeHeader(userName: user?.name ?? 'Kullanıcı'),
            ),

            // Hızlı İstatistikler
            SliverToBoxAdapter(
              child: _QuickStatsSection(recordsAsync: recordsAsync),
            ),

            // Mola Durumu Kartı
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _BreakStatusCard(),
              ),
            ),

            // SKT Uyarıları
            SliverToBoxAdapter(
              child: _SktAlertsCard(recordsAsync: recordsAsync),
            ),

            // Görev Özeti
            const SliverToBoxAdapter(
              child: _TasksSummaryCard(),
            ),

            // Hızlı Bildirimler
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: InventoryQuickNotificationsCard(),
              ),
            ),

            // Duyurular
            const SliverToBoxAdapter(
              child: _AnnouncementsCard(),
            ),

            // Alt boşluk (bottom bar için)
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hoş geldin başlığı
class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.userName});

  final String userName;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'İyi geceler';
    if (hour < 12) return 'Günaydın';
    if (hour < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }

  String _getMotivationalText() {
    final hour = DateTime.now().hour;
    final weekday = DateTime.now().weekday;

    if (weekday == 1) return 'Yeni bir hafta, yeni fırsatlar! 💪';
    if (weekday == 5) return 'Cuma enerjisi! Son hamle 🎯';
    if (hour < 10) return 'Güne enerjik başla! ☀️';
    if (hour < 14) return 'Verimli bir öğle diliyoruz 🚀';
    if (hour < 18) return 'Bitiş çizgisi yakın! 🏁';
    return 'Bugün de harika işler çıkardın! 🌟';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getGreeting()},',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.onPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.waving_hand_rounded,
                  color: colorScheme.onPrimary,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.onPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getMotivationalText(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hızlı istatistikler
class _QuickStatsSection extends StatelessWidget {
  const _QuickStatsSection({required this.recordsAsync});

  final AsyncValue<List<SktRecordModel>> recordsAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return recordsAsync.when(
      data: (records) {
        final now = DateTime.now();
        final expiredCount = records.where((r) => r.daysUntil(now) < 0).length;
        final warningCount = records.where((r) {
          final days = r.daysUntil(now);
          return days >= 0 && days <= 7;
        }).length;
        final totalCount = records.length;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.warning_amber_rounded,
                  value: expiredCount.toString(),
                  label: 'SKT Geçmiş',
                  color: colorScheme.error,
                  bgColor: colorScheme.errorContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.schedule_rounded,
                  value: warningCount.toString(),
                  label: 'Yaklaşan',
                  color: colorScheme.tertiary,
                  bgColor: colorScheme.tertiaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.inventory_2_rounded,
                  value: totalCount.toString(),
                  label: 'Toplam SKT',
                  color: colorScheme.primary,
                  bgColor: colorScheme.primaryContainer,
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: List.generate(
            3,
            (_) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: _ < 2 ? 12 : 0),
                height: 90,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Mola durumu kartı
class _BreakStatusCard extends ConsumerWidget {
  const _BreakStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
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
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.coffee_rounded,
                    color: colorScheme.secondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mola Takibi',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Günlük mola durumunuz',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ShiftsAndBreaksPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Detay'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            BreakQuickActionCard(
              onViewHistory: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ShiftsAndBreaksPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// SKT Uyarıları kartı
class _SktAlertsCard extends StatelessWidget {
  const _SktAlertsCard({required this.recordsAsync});

  final AsyncValue<List<SktRecordModel>> recordsAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
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
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.calendar_month_rounded,
                      color: colorScheme.error,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'SKT Takibi',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
              const SizedBox(height: 16),
              recordsAsync.when(
                data: (records) => _buildRecordsList(context, records),
                loading: () => const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(
                  'Yüklenemedi: $e',
                  style: TextStyle(color: colorScheme.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecordsList(BuildContext context, List<SktRecordModel> records) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    final alerts = records.where((r) {
      final days = r.daysUntil(now);
      return days <= 7;
    }).toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    if (alerts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: theme.colorScheme.secondary,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Harika! Yaklaşan veya geçmiş SKT ürünü bulunmuyor.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final preview = alerts.take(4).toList();

    return Column(
      children: preview.asMap().entries.map((entry) {
        final record = entry.value;
        final isLast = entry.key == preview.length - 1;
        return _SktAlertItem(
          record: record,
          showDivider: !isLast,
        );
      }).toList(),
    );
  }
}

class _SktAlertItem extends StatelessWidget {
  const _SktAlertItem({
    required this.record,
    this.showDivider = true,
  });

  final SktRecordModel record;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    final daysLeft = record.daysUntil(now);

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (daysLeft < 0) {
      statusColor = colorScheme.error;
      statusText = 'Geçti';
      statusIcon = Icons.error_rounded;
    } else if (daysLeft == 0) {
      statusColor = colorScheme.tertiary;
      statusText = 'Bugün';
      statusIcon = Icons.today_rounded;
    } else {
      statusColor = colorScheme.secondary;
      statusText = '$daysLeft gün';
      statusIcon = Icons.schedule_rounded;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.productName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${record.branchName} · ${record.quantity} adet',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}

/// Görev özeti kartı
class _TasksSummaryCard extends ConsumerWidget {
  const _TasksSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const BranchTasksPage(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.checklist_rounded,
                    color: colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Görevlerim',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Şube görevlerini görüntüle ve yönet',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Duyurular kartı
class _AnnouncementsCard extends StatelessWidget {
  const _AnnouncementsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
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
                      color: colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.campaign_rounded,
                      color: colorScheme.tertiary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Duyurular',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Henüz yeni duyuru bulunmuyor. Genel merkez duyuruları burada görüntülenecek.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
