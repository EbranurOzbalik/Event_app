import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../auth/screens/phone_verification_screen.dart';
import '../models/event_model.dart';
import '../services/event_service.dart';
import '../services/registration_service.dart';
import 'add_event_screen.dart';
import 'notifications_screen.dart';
import '../../qr/screens/qr_scanner_screen.dart';
import '../../qr/screens/qr_ticket_screen.dart';

const double _kPageBottomPadding = 152;

bool _isDesktopWebContext(BuildContext context) {
  if (!kIsWeb) {
    return false;
  }

  return MediaQuery.sizeOf(context).width >= 1080;
}

double _pageBottomPadding(BuildContext context) {
  return _isDesktopWebContext(context) ? 28 : _kPageBottomPadding;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _eventService = EventService();
  final _registrationService = RegistrationService();
  final _search = TextEditingController();
  final _discoverScroll = ScrollController(keepScrollOffset: false);
  final _timelineScroll = ScrollController(keepScrollOffset: false);
  final _ticketsScroll = ScrollController(keepScrollOffset: false);
  final _profileScroll = ScrollController(keepScrollOffset: false);
  Timer? _searchDebounce;

  int _tabIndex = 0;
  String _selectedCategory = 'tumu';
  String _searchQuery = '';

  String _normalizeRole(String value) {
    final role = value.trim().toLowerCase();
    if (role == 'admin' || role == 'administrator' || role == 'yonetici') {
      return 'admin';
    }
    if (role == 'moderator' || role == 'mod') {
      return 'moderator';
    }
    return 'user';
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  void _openAddEvent(String role) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEventScreen(role: role)),
    );
  }

  void _openQrScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
  }

  void _openNotifications(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(currentUserId: userId),
      ),
    );
  }

  void _openPhoneVerification({
    required String phone,
    required bool phoneVerified,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhoneVerificationScreen(
          initialPhone: phone,
          alreadyVerified: phoneVerified,
        ),
      ),
    );
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 260), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _searchQuery = value;
        if (value.trim().isNotEmpty && _selectedCategory != 'tumu') {
          _selectedCategory = 'tumu';
        }
      });
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    _discoverScroll.dispose();
    _timelineScroll.dispose();
    _ticketsScroll.dispose();
    _profileScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final uid = currentUser.uid;
    final currentEmail = currentUser.email ?? '';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text('Kullanıcı verisi bulunamadı.')),
          );
        }

        final userData = userSnapshot.data!.data()!;
        final fullName = (userData['fullName'] ?? '').toString();
        final email = (userData['email'] ?? currentEmail).toString();
        final role = _normalizeRole((userData['role'] ?? 'user').toString());
        final phone = (userData['phone'] ?? '').toString();
        final phoneVerified = userData['phoneVerified'] == true;
        final department = (userData['department'] ?? '').toString();
        final userType = (userData['userType'] ?? '').toString();
        final faculty = (userData['faculty'] ?? '').toString();
        final grade = (userData['grade'] ?? '').toString();
        final canCreate = role == 'admin' || role == 'moderator';

        final pages = <Widget>[
          _DiscoverTab(
            fullName: fullName,
            role: role,
            currentUserId: uid,
            currentUserName: fullName,
            currentUserEmail: email,
            canCreate: canCreate,
            eventService: _eventService,
            registrationService: _registrationService,
            searchController: _search,
            scrollController: _discoverScroll,
            searchQuery: _searchQuery,
            selectedCategory: _selectedCategory,
            onCategorySelected: (value) {
              setState(() => _selectedCategory = value);
            },
            onSearchChanged: _onSearchChanged,
            onClearSearch: () {
              _searchDebounce?.cancel();
              _search.clear();
              setState(() => _searchQuery = '');
            },
            onCreateEvent: canCreate ? () => _openAddEvent(role) : null,
            onScanQr: canCreate ? _openQrScanner : null,
            onOpenNotifications: () => _openNotifications(uid),
            onOpenProfile: () => setState(() => _tabIndex = 3),
          ),
          _TimelineTab(
            eventService: _eventService,
            registrationService: _registrationService,
            currentUserId: uid,
            currentUserName: fullName,
            showTicketsPanel: !canCreate,
            scrollController: _timelineScroll,
          ),
          _TicketsTab(
            currentUserId: uid,
            currentUserName: fullName,
            registrationService: _registrationService,
            eventService: _eventService,
            scrollController: _ticketsScroll,
          ),
          _ProfileTab(
            fullName: fullName,
            email: email,
            phone: phone,
            phoneVerified: phoneVerified,
            faculty: faculty,
            department: department,
            userType: userType,
            grade: grade,
            role: role,
            scrollController: _profileScroll,
            onVerifyPhone: () => _openPhoneVerification(
              phone: phone,
              phoneVerified: phoneVerified,
            ),
            onLogout: _logout,
          ),
        ];

        final effectiveIndex = !canCreate && _tabIndex == 2 ? 1 : _tabIndex;
        final userBottomIndex = effectiveIndex == 3 ? 2 : effectiveIndex;
        final selectedDesktopIndex = canCreate
            ? effectiveIndex
            : (effectiveIndex == 3 ? 3 : effectiveIndex);

        final pageView = AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final slide =
                Tween<Offset>(
                  begin: const Offset(0.06, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                );

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(effectiveIndex),
            child: pages[effectiveIndex],
          ),
        );

        if (_isDesktopWebContext(context)) {
          return Scaffold(
            body: Stack(
              children: [
                const _BackdropLayer(),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                    child: Column(
                      children: [
                        _DesktopTopBar(
                          fullName: fullName,
                          role: role,
                          canCreate: canCreate,
                          selectedIndex: selectedDesktopIndex,
                          onSelected: (index) {
                            setState(() {
                              if (!canCreate && index == 3) {
                                _tabIndex = 3;
                              } else {
                                _tabIndex = index;
                              }
                            });
                          },
                          onCreateEvent: canCreate
                              ? () => _openAddEvent(role)
                              : null,
                          onScanQr: canCreate ? _openQrScanner : null,
                          onOpenNotifications: () => _openNotifications(uid),
                          onLogout: _logout,
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.58),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.88),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF0F172A,
                                  ).withValues(alpha: 0.08),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: pageView,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: Stack(children: [const _BackdropLayer(), pageView]),
          bottomNavigationBar: canCreate
              ? _BottomDock(
                  selectedIndex: effectiveIndex,
                  onSelected: (index) => setState(() => _tabIndex = index),
                  onCenterTap: () => _openAddEvent(role),
                )
              : _UserBottomDock(
                  selectedIndex: userBottomIndex,
                  onSelected: (index) {
                    setState(() {
                      if (index == 2) {
                        _tabIndex = 3;
                        return;
                      }
                      _tabIndex = index;
                    });
                  },
                ),
        );
      },
    );
  }
}

class _BackdropLayer extends StatelessWidget {
  const _BackdropLayer();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF8F5F0), Color(0xFFF6FAFF), Color(0xFFFDF4EC)],
            ),
          ),
        ),
        Positioned(
          top: -130,
          left: -80,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFB7185).withValues(alpha: 0.12),
            ),
          ),
        ),
        Positioned(
          top: 120,
          right: -70,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.14),
            ),
          ),
        ),
        Positioned(
          bottom: -130,
          left: -30,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF22C55E).withValues(alpha: 0.12),
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  final String fullName;
  final String role;
  final bool canCreate;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback? onCreateEvent;
  final VoidCallback? onScanQr;
  final VoidCallback onOpenNotifications;
  final VoidCallback onLogout;

  const _DesktopTopBar({
    required this.fullName,
    required this.role,
    required this.canCreate,
    required this.selectedIndex,
    required this.onSelected,
    required this.onCreateEvent,
    required this.onScanQr,
    required this.onOpenNotifications,
    required this.onLogout,
  });

  List<_DesktopNavItem> _items() {
    if (canCreate) {
      return const [
        _DesktopNavItem(0, Icons.home_rounded, 'Ana Sayfa'),
        _DesktopNavItem(1, Icons.calendar_month_rounded, 'Takvim'),
        _DesktopNavItem(2, Icons.confirmation_number_outlined, 'Biletler'),
        _DesktopNavItem(3, Icons.person_pin_circle_outlined, 'Profil'),
      ];
    }

    return const [
      _DesktopNavItem(0, Icons.home_rounded, 'Ana Sayfa'),
      _DesktopNavItem(1, Icons.calendar_month_rounded, 'Takvim'),
      _DesktopNavItem(3, Icons.person_pin_circle_outlined, 'Profil'),
    ];
  }

  String _roleLabel(String value) {
    switch (value) {
      case 'admin':
        return 'Admin';
      case 'moderator':
        return 'Moderatör';
      default:
        return 'Kullanıcı';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final items = _items();
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 1320;
    final veryCompact = width < 1180;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF9F7F2), Color(0xFFF2F7FF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                      ),
                    ),
                    child: const Icon(
                      Icons.celebration_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Event App',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      Text(
                        'Campus Events',
                        style: textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: onOpenNotifications,
                icon: const Icon(Icons.notifications_none_rounded),
                tooltip: 'Bildirimler',
              ),
              if (canCreate) ...[
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onCreateEvent,
                  child: Icon(
                    compact ? Icons.add_rounded : Icons.add_task_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onScanQr,
                  child: Icon(
                    compact
                        ? Icons.qr_code_scanner_rounded
                        : Icons.qr_code_2_rounded,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFFDBEAFE),
                      child: Text(
                        _initials(fullName),
                        style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!veryCompact)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName.trim().isEmpty ? 'Kullanıcı' : fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              _roleLabel(role),
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Çıkış',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in items)
                _DesktopTopNavChip(
                  icon: item.icon,
                  label: item.label,
                  active: selectedIndex == item.index,
                  onTap: () => onSelected(item.index),
                  compact: compact,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DesktopNavItem {
  final int index;
  final IconData icon;
  final String label;

  const _DesktopNavItem(this.index, this.icon, this.label);
}

class _DesktopTopNavChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool compact;

  const _DesktopTopNavChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF1D4ED8) : const Color(0xFF475569);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 8 : 9,
          ),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFFDDEAFE), Color(0xFFEFF6FF)],
                  )
                : null,
            color: active ? null : Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? const Color(0xFFBFDBFE)
                  : const Color(0xFFE2E8F0).withValues(alpha: 0.8),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              if (!compact) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomDock extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback? onCenterTap;

  const _BottomDock({
    required this.selectedIndex,
    required this.onSelected,
    required this.onCenterTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: SizedBox(
        height: 96 + bottomInset,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 76 + bottomInset,
                padding: EdgeInsets.fromLTRB(
                  8,
                  14,
                  8,
                  bottomInset > 0 ? bottomInset : 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.97),
                  borderRadius: BorderRadius.circular(34),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.1),
                      blurRadius: 24,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _DockTabButton(
                        icon: Icons.home_rounded,
                        active: selectedIndex == 0,
                        onTap: () => onSelected(0),
                      ),
                    ),
                    Expanded(
                      child: _DockTabButton(
                        icon: Icons.calendar_month_rounded,
                        active: selectedIndex == 1,
                        onTap: () => onSelected(1),
                      ),
                    ),
                    const Expanded(child: SizedBox()),
                    Expanded(
                      child: _DockTabButton(
                        icon: Icons.confirmation_number_outlined,
                        active: selectedIndex == 2,
                        onTap: () => onSelected(2),
                      ),
                    ),
                    Expanded(
                      child: _DockTabButton(
                        icon: Icons.person_pin_circle_outlined,
                        active: selectedIndex == 3,
                        onTap: () => onSelected(3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Center(child: _DockCenterButton(onTap: onCenterTap)),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserBottomDock extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _UserBottomDock({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Container(
        height: 76 + bottomInset,
        padding: EdgeInsets.fromLTRB(
          10,
          12,
          10,
          bottomInset > 0 ? bottomInset : 10,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(34),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.1),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _DockTabButton(
                icon: Icons.home_rounded,
                active: selectedIndex == 0,
                onTap: () => onSelected(0),
              ),
            ),
            Expanded(
              child: _DockTabButton(
                icon: Icons.calendar_month_rounded,
                active: selectedIndex == 1,
                onTap: () => onSelected(1),
              ),
            ),
            Expanded(
              child: _DockTabButton(
                icon: Icons.person_pin_circle_outlined,
                active: selectedIndex == 2,
                onTap: () => onSelected(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockTabButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _DockTabButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF2563EB);
    final inactiveColor = const Color(0xFF475569);

    return InkResponse(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 30, color: active ? activeColor : inactiveColor),
          const SizedBox(height: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: active ? 9 : 0,
            height: active ? 9 : 0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? activeColor : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}

class _DockCenterButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _DockCenterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const baseColor = Color(0xFF2F72C8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 68,
          height: 68,
          decoration: BoxDecoration(shape: BoxShape.circle, color: baseColor),
          child: const Icon(Icons.add_rounded, size: 27, color: Colors.white),
        ),
      ),
    );
  }
}

class _DiscoverTab extends StatelessWidget {
  final String fullName;
  final String role;
  final String currentUserId;
  final String currentUserName;
  final String currentUserEmail;
  final bool canCreate;
  final EventService eventService;
  final RegistrationService registrationService;
  final TextEditingController searchController;
  final ScrollController scrollController;
  final String searchQuery;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback? onCreateEvent;
  final VoidCallback? onScanQr;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfile;

  const _DiscoverTab({
    required this.fullName,
    required this.role,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserEmail,
    required this.canCreate,
    required this.eventService,
    required this.registrationService,
    required this.searchController,
    required this.scrollController,
    required this.searchQuery,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onCreateEvent,
    required this.onScanQr,
    required this.onOpenNotifications,
    required this.onOpenProfile,
  });

  List<String> _buildCategories(List<EventModel> events) {
    const priority = [
      'konser',
      'sinema',
      'tiyatro',
      'spor',
      'sanat',
      'yemek',
      'genel',
    ];

    final discovered = <String>{};
    for (final event in events) {
      discovered.add(_inferVisualCategory(event));
    }

    final categories = <String>['tumu'];

    for (final code in priority) {
      if (discovered.contains(code)) {
        categories.add(code);
      }
    }

    for (final code in discovered) {
      if (!categories.contains(code)) {
        categories.add(code);
      }
    }

    return categories;
  }

  List<EventModel> _filterEvents(
    List<EventModel> events, {
    required String category,
    required String query,
  }) {
    var filtered = events.where((event) => event.isActive).toList();

    final normalizedQuery = _normalizeSearch(query);

    if (normalizedQuery.isNotEmpty) {
      filtered = filtered
          .where((event) => _matchesSearch(event, normalizedQuery))
          .toList();
    }

    if (category != 'tumu') {
      filtered = filtered
          .where((event) => _inferVisualCategory(event) == category)
          .toList();
    }

    return filtered;
  }

  bool _matchesSearch(EventModel event, String normalizedQuery) {
    final source = _normalizeSearch(
      '${event.title} ${event.description} ${event.location} ${event.date} ${event.category} ${_categoryLabel(_inferVisualCategory(event))}',
    );

    if (source.contains(normalizedQuery)) {
      return true;
    }

    final tokens = normalizedQuery
        .split(' ')
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .toList();

    if (tokens.isEmpty) {
      return true;
    }

    return tokens.every(source.contains);
  }

  String _firstName() {
    if (fullName.trim().isEmpty) {
      return 'Etkinlikçi';
    }

    return fullName.trim().split(RegExp(r'\s+')).first;
  }

  Widget _buildDesktopDiscover({
    required BuildContext context,
    required bool loadingEvents,
    required List<String> categories,
    required String effectiveCategory,
    required List<EventModel> allEvents,
    required List<EventModel> filteredEvents,
    required EventModel? featured,
    required List<EventModel> upcoming,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final hasActiveFilter =
        searchQuery.trim().isNotEmpty || effectiveCategory != 'tumu';

    return SafeArea(
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        children: [
          if (loadingEvents)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Merhaba, ${_firstName()}',
                            style: textTheme.titleLarge?.copyWith(
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Etkinlikleri filtrele, katıl ve biletini tek panelden yönet.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: TextField(
                        controller: searchController,
                        onChanged: onSearchChanged,
                        onSubmitted: onSearchChanged,
                        textInputAction: TextInputAction.search,
                        onTapOutside: (_) {
                          FocusScope.of(context).unfocus();
                        },
                        decoration: InputDecoration(
                          hintText: 'Konser, mekan, açıklama ara...',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: searchQuery.trim().isEmpty
                              ? null
                              : IconButton(
                                  onPressed: onClearSearch,
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: registrationService.getMyRegistrations(
                        userId: currentUserId,
                      ),
                      builder: (context, snapshot) {
                        final unreadCount = snapshot.data?.docs.length ?? 0;

                        return Badge(
                          isLabelVisible: unreadCount > 0,
                          label: Text(unreadCount > 9 ? '9+' : '$unreadCount'),
                          child: IconButton.filledTonal(
                            onPressed: onOpenNotifications,
                            icon: const Icon(Icons.notifications_none_rounded),
                            tooltip: 'Bildirimler',
                            style: IconButton.styleFrom(
                              minimumSize: const Size(46, 46),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: onOpenProfile,
                      icon: const Icon(Icons.person_rounded),
                      tooltip: 'Profil',
                      style: IconButton.styleFrom(
                        minimumSize: const Size(46, 46),
                        foregroundColor: const Color(0xFF1D4ED8),
                        backgroundColor: const Color(0xFFEFF6FF),
                      ),
                    ),
                    if (canCreate) ...[
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: onScanQr,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        tooltip: 'QR Okut',
                        style: IconButton.styleFrom(
                          minimumSize: const Size(46, 46),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((code) {
                      final active = code == effectiveCategory;
                      return InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => onCategorySelected(code),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? _categoryColor(code)
                                : Colors.white.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: active
                                  ? _categoryColor(code)
                                  : Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _categoryEmoji(code),
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _categoryLabel(code),
                                style: TextStyle(
                                  color: active
                                      ? Colors.white
                                      : const Color(0xFF475569),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Öne Çıkan',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${filteredEvents.length} sonuç',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (canCreate) ...[
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: onCreateEvent,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Etkinlik Ekle'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (featured != null)
                      _FeaturedEventCard(
                        event: featured,
                        currentUserId: currentUserId,
                        currentUserName: currentUserName,
                        currentUserEmail: currentUserEmail,
                        registrationService: registrationService,
                      )
                    else
                      const _EmptyDiscoverCard(
                        title: 'Henüz etkinlik yok',
                        subtitle:
                            'İlk etkinliği oluşturarak topluluğu canlandır.',
                      ),
                    const SizedBox(height: 18),
                    Text(
                      'Yaklaşan Etkinlikler',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (upcoming.isEmpty)
                      (filteredEvents.isEmpty
                          ? _EmptyDiscoverCard(
                              title: 'Filtreye uygun etkinlik bulunamadı',
                              subtitle:
                                  'Aramanı temizleyebilir veya farklı bir kategori deneyebilirsin.',
                              onReset: hasActiveFilter
                                  ? () {
                                      if (effectiveCategory != 'tumu') {
                                        onCategorySelected('tumu');
                                      }
                                      if (searchQuery.trim().isNotEmpty) {
                                        onClearSearch();
                                      }
                                    }
                                  : null,
                            )
                          : const _EmptyDiscoverCard(
                              title: 'Başka yaklaşan etkinlik yok',
                              subtitle:
                                  'Gösterilen etkinlik filtreye uygun tek seçenek.',
                            ))
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final columns = width >= 1350
                              ? 3
                              : (width >= 760 ? 2 : 1);
                          const spacing = 12.0;
                          final cardWidth =
                              (width - ((columns - 1) * spacing)) / columns;

                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: [
                              for (final event in upcoming)
                                SizedBox(
                                  width: cardWidth,
                                  child: _UpcomingEventCard(
                                    event: event,
                                    currentUserId: currentUserId,
                                    currentUserName: currentUserName,
                                    currentUserEmail: currentUserEmail,
                                    registrationService: registrationService,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: registrationService.getMyRegistrations(
                        userId: currentUserId,
                      ),
                      builder: (context, regSnapshot) {
                        final joinedCount = regSnapshot.data?.docs.length ?? 0;

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Özet',
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _StatChip(
                                value: '$joinedCount',
                                label: 'Katıldığın Etkinlik',
                                color: const Color(0xFF2563EB),
                              ),
                              const SizedBox(height: 8),
                              _StatChip(
                                value: '${allEvents.length}',
                                label: 'Toplam Etkinlik',
                                color: const Color(0xFFDB2777),
                              ),
                              const SizedBox(height: 8),
                              _StatChip(
                                value: role.toUpperCase(),
                                label: 'Kullanıcı Rolü',
                                color: const Color(0xFF0F766E),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bu Hafta Radarda',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (upcoming.isEmpty)
                            const Text(
                              'Filtreye uygun yaklaşan etkinlik yok.',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else
                            ...upcoming.take(5).map((event) {
                              final code = _inferVisualCategory(event);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  10,
                                  10,
                                  10,
                                ),
                                decoration: BoxDecoration(
                                  color: _categoryColor(
                                    code,
                                  ).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      _categoryEmoji(code),
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            event.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFF0F172A),
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _displayEventDate(event),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<List<EventModel>>(
      stream: eventService.getEvents(),
      initialData: const <EventModel>[],
      builder: (context, snapshot) {
        final allEvents = snapshot.data ?? const <EventModel>[];
        final loadingEvents =
            snapshot.connectionState == ConnectionState.waiting &&
            allEvents.isEmpty;
        final categories = _buildCategories(allEvents);
        final effectiveCategory = categories.contains(selectedCategory)
            ? selectedCategory
            : 'tumu';
        final hasActiveFilter =
            searchQuery.trim().isNotEmpty || effectiveCategory != 'tumu';

        final filteredEvents = _filterEvents(
          allEvents,
          category: effectiveCategory,
          query: searchQuery,
        );

        final featured = filteredEvents.isNotEmpty
            ? filteredEvents.first
            : (hasActiveFilter
                  ? null
                  : (allEvents.isNotEmpty ? allEvents.first : null));

        final upcoming = filteredEvents
            .where((event) => featured == null || event.id != featured.id)
            .toList();

        if (_isDesktopWebContext(context)) {
          return _buildDesktopDiscover(
            context: context,
            loadingEvents: loadingEvents,
            categories: categories,
            effectiveCategory: effectiveCategory,
            allEvents: allEvents,
            filteredEvents: filteredEvents,
            featured: featured,
            upcoming: upcoming,
          );
        }

        return SafeArea(
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              _pageBottomPadding(context),
            ),
            children: [
              if (loadingEvents)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Merhaba, ${_firstName()} 👋',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF5C667A),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Bugün ne keşfetmek istersin?',
                                style: textTheme.titleLarge?.copyWith(
                                  color: const Color(0xFF111827),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: registrationService.getMyRegistrations(
                            userId: currentUserId,
                          ),
                          builder: (context, snapshot) {
                            final unreadCount = snapshot.data?.docs.length ?? 0;

                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                IconButton.filledTonal(
                                  onPressed: onOpenNotifications,
                                  icon: const Icon(
                                    Icons.notifications_none_rounded,
                                  ),
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(44, 44),
                                    foregroundColor: const Color(0xFF3F3CBB),
                                    backgroundColor: const Color(0xFFEEF2FF),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Positioned(
                                    top: -2,
                                    right: -2,
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 18,
                                        minHeight: 18,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          unreadCount > 9
                                              ? '9+'
                                              : '$unreadCount',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: onOpenProfile,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                _initials(fullName),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            onChanged: onSearchChanged,
                            onSubmitted: onSearchChanged,
                            textInputAction: TextInputAction.search,
                            onTapOutside: (_) {
                              FocusScope.of(context).unfocus();
                            },
                            decoration: InputDecoration(
                              hintText: 'Konser, mekan, açıklama ara...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: searchQuery.trim().isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: onClearSearch,
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                            ),
                          ),
                        ),
                        if (canCreate) ...[
                          const SizedBox(width: 10),
                          IconButton.filledTonal(
                            onPressed: onScanQr,
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(52, 52),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final code = categories[index];
                    final active = code == effectiveCategory;

                    return InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => onCategorySelected(code),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? _categoryColor(code)
                              : Colors.white.withValues(alpha: 0.74),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: active
                                ? _categoryColor(code)
                                : Colors.white.withValues(alpha: 0.9),
                          ),
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: _categoryColor(
                                      code,
                                    ).withValues(alpha: 0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Text(
                              _categoryEmoji(code),
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _categoryLabel(code),
                              style: TextStyle(
                                color: active
                                    ? Colors.white
                                    : const Color(0xFF475569),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, index) => const SizedBox(width: 8),
                  itemCount: categories.length,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    'Öne Çıkan',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const Spacer(),
                  if (canCreate)
                    TextButton.icon(
                      onPressed: onCreateEvent,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Etkinlik Ekle'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (featured != null)
                _FeaturedEventCard(
                  event: featured,
                  currentUserId: currentUserId,
                  currentUserName: currentUserName,
                  currentUserEmail: currentUserEmail,
                  registrationService: registrationService,
                )
              else
                const _EmptyDiscoverCard(
                  title: 'Henüz etkinlik yok',
                  subtitle: 'İlk etkinliği oluşturarak topluluğu canlandır.',
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Yaklaşan Etkinlikler',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${filteredEvents.length} sonuç',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (upcoming.isEmpty)
                (filteredEvents.isEmpty
                    ? _EmptyDiscoverCard(
                        title: 'Filtreye uygun etkinlik bulunamadı',
                        subtitle:
                            'Aramanı temizleyebilir veya farklı bir kategori deneyebilirsin.',
                        onReset:
                            searchQuery.trim().isNotEmpty ||
                                effectiveCategory != 'tumu'
                            ? () {
                                if (effectiveCategory != 'tumu') {
                                  onCategorySelected('tumu');
                                }
                                if (searchQuery.trim().isNotEmpty) {
                                  onClearSearch();
                                }
                              }
                            : null,
                      )
                    : const _EmptyDiscoverCard(
                        title: 'Başka yaklaşan etkinlik yok',
                        subtitle:
                            'Gösterilen etkinlik filtreye uygun tek seçenek.',
                      ))
              else
                ...upcoming.map(
                  (event) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _UpcomingEventCard(
                      event: event,
                      currentUserId: currentUserId,
                      currentUserName: currentUserName,
                      currentUserEmail: currentUserEmail,
                      registrationService: registrationService,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: registrationService.getMyRegistrations(
                  userId: currentUserId,
                ),
                builder: (context, regSnapshot) {
                  final joinedCount = regSnapshot.data?.docs.length ?? 0;

                  return Row(
                    children: [
                      Expanded(
                        child: _StatChip(
                          value: '$joinedCount',
                          label: 'Katıldığın',
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatChip(
                          value: '${allEvents.length}',
                          label: 'Toplam',
                          color: const Color(0xFFDB2777),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatChip(
                          value: role.toUpperCase(),
                          label: 'Rol',
                          color: const Color(0xFF0F766E),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyDiscoverCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onReset;

  const _EmptyDiscoverCard({
    required this.title,
    required this.subtitle,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onReset != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Filtreyi Sıfırla'),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeaturedEventCard extends StatefulWidget {
  final EventModel event;
  final String currentUserId;
  final String currentUserName;
  final String currentUserEmail;
  final RegistrationService registrationService;

  const _FeaturedEventCard({
    required this.event,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserEmail,
    required this.registrationService,
  });

  @override
  State<_FeaturedEventCard> createState() => _FeaturedEventCardState();
}

class _FeaturedEventCardState extends State<_FeaturedEventCard> {
  bool _joining = false;

  Future<void> _joinEvent() async {
    setState(() => _joining = true);

    try {
      await widget.registrationService.joinEvent(
        eventId: widget.event.id,
        userId: widget.currentUserId,
        userName: widget.currentUserName,
        userEmail: widget.currentUserEmail,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Etkinliğe katıldın.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _joining = false);
      }
    }
  }

  void _showTicket() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QrTicketScreen(
          eventId: widget.event.id,
          eventTitle: widget.event.title,
          userId: widget.currentUserId,
          userName: widget.currentUserName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final categoryCode = _inferVisualCategory(event);
    final gradient = _categoryGradient(categoryCode);

    return Container(
      height: 256,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradient.first, gradient.last],
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withValues(alpha: 0.32),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: _eventCoverImage(
                event: event,
                fit: BoxFit.cover,
                fallback: Container(
                  color: gradient.first.withValues(alpha: 0.3),
                  child: Center(
                    child: Text(
                      _categoryEmoji(categoryCode),
                      style: const TextStyle(fontSize: 46),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.24),
                    Colors.black.withValues(alpha: 0.44),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -45,
            right: -20,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -35,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_categoryEmoji(categoryCode)}  ${_categoryLabel(categoryCode)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'POPÜLER',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 24,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _displayEventDate(event),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.94),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.place_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  event.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.94),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    StreamBuilder<bool>(
                      stream: widget.registrationService.isJoined(
                        eventId: event.id,
                        userId: widget.currentUserId,
                      ),
                      builder: (context, snapshot) {
                        final joined = snapshot.data ?? false;

                        if (joined) {
                          return OutlinedButton.icon(
                            onPressed: _showTicket,
                            icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                            label: const Text('Biletim'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                          );
                        }

                        return ElevatedButton(
                          onPressed: _joining ? null : _joinEvent,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: gradient.first,
                            minimumSize: const Size(104, 46),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          child: _joining
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: gradient.first,
                                  ),
                                )
                              : const Text('Katıl'),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingEventCard extends StatefulWidget {
  final EventModel event;
  final String currentUserId;
  final String currentUserName;
  final String currentUserEmail;
  final RegistrationService registrationService;

  const _UpcomingEventCard({
    required this.event,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserEmail,
    required this.registrationService,
  });

  @override
  State<_UpcomingEventCard> createState() => _UpcomingEventCardState();
}

class _UpcomingEventCardState extends State<_UpcomingEventCard> {
  bool _joining = false;
  bool _favorited = false;

  Future<void> _joinEvent() async {
    setState(() => _joining = true);

    try {
      await widget.registrationService.joinEvent(
        eventId: widget.event.id,
        userId: widget.currentUserId,
        userName: widget.currentUserName,
        userEmail: widget.currentUserEmail,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Etkinliğe katıldın.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _joining = false);
      }
    }
  }

  void _showTicket() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QrTicketScreen(
          eventId: widget.event.id,
          eventTitle: widget.event.title,
          userId: widget.currentUserId,
          userName: widget.currentUserName,
        ),
      ),
    );
  }

  void _toggleFavorite() {
    setState(() => _favorited = !_favorited);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _favorited ? 'Favorilere eklendi.' : 'Favorilerden kaldırıldı.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final categoryCode = _inferVisualCategory(event);
    final badgeColor = _categoryColor(categoryCode);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.antiAlias,
            child: _eventCoverImage(
              event: event,
              fit: BoxFit.cover,
              fallback: Center(
                child: Text(
                  _categoryEmoji(categoryCode),
                  style: const TextStyle(fontSize: 34),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _categoryLabel(categoryCode).toUpperCase(),
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _toggleFavorite,
                      visualDensity: VisualDensity.compact,
                      splashRadius: 18,
                      icon: Icon(
                        _favorited
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: _favorited
                            ? const Color(0xFFE11D48)
                            : const Color(0xFF64748B).withValues(alpha: 0.8),
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _displayEventDate(event),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.place_rounded,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                StreamBuilder<bool>(
                  stream: widget.registrationService.isJoined(
                    eventId: event.id,
                    userId: widget.currentUserId,
                  ),
                  builder: (context, snapshot) {
                    final joined = snapshot.data ?? false;

                    if (joined) {
                      return OutlinedButton.icon(
                        onPressed: _showTicket,
                        icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                        label: const Text('Biletim'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          minimumSize: const Size(118, 40),
                        ),
                      );
                    }

                    return ElevatedButton(
                      onPressed: _joining ? null : _joinEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: badgeColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(112, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: _joining
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Katıl'),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineTab extends StatefulWidget {
  final EventService eventService;
  final RegistrationService registrationService;
  final String currentUserId;
  final String currentUserName;
  final bool showTicketsPanel;
  final ScrollController scrollController;

  const _TimelineTab({
    required this.eventService,
    required this.registrationService,
    required this.currentUserId,
    required this.currentUserName,
    required this.showTicketsPanel,
    required this.scrollController,
  });

  @override
  State<_TimelineTab> createState() => _TimelineTabState();
}

class _TimelineTabState extends State<_TimelineTab> {
  late DateTime _selectedDate;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _visibleMonth = DateTime(now.year, now.month, 1);
  }

  DateTime _clampDate(DateTime value, DateTime min, DateTime max) {
    final date = DateTime(value.year, value.month, value.day);
    if (date.isBefore(min)) {
      return DateTime(min.year, min.month, min.day);
    }
    if (date.isAfter(max)) {
      return DateTime(max.year, max.month, max.day);
    }
    return date;
  }

  bool _canNavigateToMonth(DateTime candidate, DateTime min, DateTime max) {
    final start = DateTime(candidate.year, candidate.month, 1);
    final end = DateTime(candidate.year, candidate.month + 1, 0);
    return !end.isBefore(min) && !start.isAfter(max);
  }

  void _changeMonth(int delta, DateTime minDate, DateTime maxDate) {
    final candidate = DateTime(_visibleMonth.year, _visibleMonth.month + delta);

    if (!_canNavigateToMonth(candidate, minDate, maxDate)) {
      return;
    }

    final firstDay = DateTime(candidate.year, candidate.month, 1);

    setState(() {
      _visibleMonth = firstDay;
      _selectedDate = _clampDate(firstDay, minDate, maxDate);
    });
  }

  void _selectDate(DateTime value, DateTime minDate, DateTime maxDate) {
    final selected = _clampDate(value, minDate, maxDate);
    setState(() {
      _selectedDate = selected;
      _visibleMonth = DateTime(selected.year, selected.month, 1);
    });
  }

  Map<String, List<EventModel>> _groupJoinedEventsByDate(
    List<EventModel> events,
    Set<String> joinedEventIds,
  ) {
    final grouped = <String, List<EventModel>>{};

    for (final event in events) {
      if (!joinedEventIds.contains(event.id)) {
        continue;
      }

      final date = _eventDateForUi(event);
      if (date == null) {
        continue;
      }

      final key = _dateKey(date);
      grouped.putIfAbsent(key, () => <EventModel>[]).add(event);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final minDate = DateTime(now.year - 3, 1, 1);
    final maxDate = DateTime(now.year + 5, 12, 31);

    return SafeArea(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: widget.registrationService.getMyRegistrations(
          userId: widget.currentUserId,
        ),
        builder: (context, registrationSnapshot) {
          final joinedEventIds = <String>{};
          for (final doc
              in registrationSnapshot.data?.docs ??
                  const <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
            final eventId = (doc.data()['eventId'] ?? '').toString().trim();
            if (eventId.isNotEmpty) {
              joinedEventIds.add(eventId);
            }
          }

          return StreamBuilder<List<EventModel>>(
            stream: widget.eventService.getEvents(),
            initialData: const <EventModel>[],
            builder: (context, snapshot) {
              final events = snapshot.data ?? const <EventModel>[];
              final loadingEvents =
                  snapshot.connectionState == ConnectionState.waiting &&
                  events.isEmpty;
              final loadingRegistrations =
                  registrationSnapshot.connectionState ==
                      ConnectionState.waiting &&
                  joinedEventIds.isEmpty;

              final selectedEvents = events.where((event) {
                final date = _eventDateForUi(event);
                return date != null && _isSameDate(date, _selectedDate);
              }).toList();

              final joinedEventsByDate = _groupJoinedEventsByDate(
                events,
                joinedEventIds,
              );

              final canGoPrev = _canNavigateToMonth(
                DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1),
                minDate,
                maxDate,
              );
              final canGoNext = _canNavigateToMonth(
                DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1),
                minDate,
                maxDate,
              );

              Widget selectedEventsContent() {
                if (events.isEmpty) {
                  return const _EmptyDiscoverCard(
                    title: 'Takvim boş',
                    subtitle: 'Yeni etkinlik eklendiğinde burada listelenecek.',
                  );
                }

                if (selectedEvents.isEmpty) {
                  return const _EmptyDiscoverCard(
                    title: 'Bu tarihte etkinlik yok',
                    subtitle:
                        'Başka bir gün seçerek etkinlikleri görebilirsin.',
                  );
                }

                return Column(
                  children: [
                    for (final event in selectedEvents)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                        child: Row(
                          children: [
                            Builder(
                              builder: (context) {
                                final categoryCode = _inferVisualCategory(
                                  event,
                                );

                                return Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: _categoryColor(
                                      categoryCode,
                                    ).withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: _eventCoverImage(
                                    event: event,
                                    fit: BoxFit.cover,
                                    fallback: Center(
                                      child: Text(
                                        _categoryEmoji(categoryCode),
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${_displayEventDate(event)} • ${event.location}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              }

              final calendarCard = Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.94),
                  ),
                ),
                child: _EventMonthCalendar(
                  visibleMonth: _visibleMonth,
                  selectedDate: _selectedDate,
                  firstDate: minDate,
                  lastDate: maxDate,
                  joinedEventsByDate: joinedEventsByDate,
                  onDateSelected: (value) =>
                      _selectDate(value, minDate, maxDate),
                  onPreviousMonth: canGoPrev
                      ? () => _changeMonth(-1, minDate, maxDate)
                      : null,
                  onNextMonth: canGoNext
                      ? () => _changeMonth(1, minDate, maxDate)
                      : null,
                ),
              );

              final dateHeader = Row(
                children: [
                  Text(
                    '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${selectedEvents.length} etkinlik',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              );

              if (_isDesktopWebContext(context)) {
                return ListView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                  children: [
                    if (loadingEvents || loadingRegistrations)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: LinearProgressIndicator(minHeight: 3),
                      ),
                    Row(
                      children: [
                        Text(
                          'Takvim',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.84),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${selectedEvents.length} etkinlik',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 6,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 860),
                            child: calendarCard,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.84),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.92),
                                  ),
                                ),
                                child: dateHeader,
                              ),
                              const SizedBox(height: 10),
                              selectedEventsContent(),
                              if (widget.showTicketsPanel) ...[
                                const SizedBox(height: 8),
                                _TimelineTicketsPanel(
                                  currentUserId: widget.currentUserId,
                                  currentUserName: widget.currentUserName,
                                  registrationService:
                                      widget.registrationService,
                                  eventService: widget.eventService,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return ListView(
                controller: widget.scrollController,
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  _pageBottomPadding(context),
                ),
                children: [
                  if (loadingEvents || loadingRegistrations)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: LinearProgressIndicator(minHeight: 3),
                    ),
                  Text(
                    'Takvim',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  calendarCard,
                  const SizedBox(height: 14),
                  dateHeader,
                  const SizedBox(height: 10),
                  selectedEventsContent(),
                  if (widget.showTicketsPanel) ...[
                    const SizedBox(height: 8),
                    _TimelineTicketsPanel(
                      currentUserId: widget.currentUserId,
                      currentUserName: widget.currentUserName,
                      registrationService: widget.registrationService,
                      eventService: widget.eventService,
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _TimelineTicketsPanel extends StatelessWidget {
  final String currentUserId;
  final String currentUserName;
  final RegistrationService registrationService;
  final EventService eventService;

  const _TimelineTicketsPanel({
    required this.currentUserId,
    required this.currentUserName,
    required this.registrationService,
    required this.eventService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: registrationService.getMyRegistrations(userId: currentUserId),
      builder: (context, registrationSnapshot) {
        final registrations = registrationSnapshot.data?.docs ?? [];

        return StreamBuilder<List<EventModel>>(
          stream: eventService.getEvents(),
          initialData: const <EventModel>[],
          builder: (context, eventSnapshot) {
            final events = eventSnapshot.data ?? const <EventModel>[];
            final eventById = {for (final event in events) event.id: event};

            return Container(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.92)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Biletler ve QR',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${registrations.length} bilet',
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (registrations.isEmpty)
                    const Text(
                      'Henüz biletin yok. Bir etkinliğe katıldığında QR biletin burada görünür.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    ...registrations.map((registrationDoc) {
                      final data = registrationDoc.data();
                      final eventId = (data['eventId'] ?? '').toString();
                      final checkedIn = data['checkedIn'] == true;
                      final event = eventById[eventId];
                      final title = event?.title ?? 'Etkinlik';
                      final subtitle = event == null
                          ? 'Tarih yakında'
                          : '${_displayEventDate(event)} • ${event.location}';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.96),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: checkedIn
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => QrTicketScreen(
                                            eventId: eventId,
                                            eventTitle: title,
                                            userId: currentUserId,
                                            userName:
                                                currentUserName
                                                    .trim()
                                                    .isNotEmpty
                                                ? currentUserName
                                                : 'Kullanıcı',
                                          ),
                                        ),
                                      );
                                    },
                              icon: Icon(
                                checkedIn
                                    ? Icons.verified_rounded
                                    : Icons.qr_code_rounded,
                                size: 18,
                              ),
                              label: Text(checkedIn ? 'Okutuldu' : 'QR'),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _EventMonthCalendar extends StatelessWidget {
  final DateTime visibleMonth;
  final DateTime selectedDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Map<String, List<EventModel>> joinedEventsByDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback? onPreviousMonth;
  final VoidCallback? onNextMonth;

  const _EventMonthCalendar({
    required this.visibleMonth,
    required this.selectedDate,
    required this.firstDate,
    required this.lastDate,
    required this.joinedEventsByDate,
    required this.onDateSelected,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final daysInMonth = DateTime(
      visibleMonth.year,
      visibleMonth.month + 1,
      0,
    ).day;
    final leadingEmptyCount = (monthStart.weekday + 6) % 7;
    var totalCellCount = leadingEmptyCount + daysInMonth;
    if (totalCellCount % 7 != 0) {
      totalCellCount += 7 - (totalCellCount % 7);
    }

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onPreviousMonth,
              icon: const Icon(Icons.chevron_left_rounded),
              style: IconButton.styleFrom(
                minimumSize: const Size(40, 40),
                foregroundColor: const Color(0xFF334155),
                backgroundColor: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            Expanded(
              child: Text(
                _monthLabelTr(visibleMonth),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  fontSize: 16,
                ),
              ),
            ),
            IconButton(
              onPressed: onNextMonth,
              icon: const Icon(Icons.chevron_right_rounded),
              style: IconButton.styleFrom(
                minimumSize: const Size(40, 40),
                foregroundColor: const Color(0xFF334155),
                backgroundColor: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: const [
            _WeekLabel('Pzt'),
            _WeekLabel('Sal'),
            _WeekLabel('Çar'),
            _WeekLabel('Per'),
            _WeekLabel('Cum'),
            _WeekLabel('Cmt'),
            _WeekLabel('Paz'),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final gridWidth = constraints.maxWidth;
            final desktop = _isDesktopWebContext(context);
            final ratio = desktop
                ? (gridWidth >= 980 ? 1.52 : 1.34)
                : (gridWidth >= 600 ? 1.05 : 0.82);

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: totalCellCount,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: ratio,
              ),
              itemBuilder: (context, index) {
                if (index < leadingEmptyCount) {
                  return const SizedBox.shrink();
                }

                final dayNumber = index - leadingEmptyCount + 1;
                if (dayNumber > daysInMonth) {
                  return const SizedBox.shrink();
                }

                final date = DateTime(
                  visibleMonth.year,
                  visibleMonth.month,
                  dayNumber,
                );
                final disabled =
                    date.isBefore(firstDate) || date.isAfter(lastDate);
                final selected = _isSameDate(date, selectedDate);
                final logos =
                    joinedEventsByDate[_dateKey(date)] ?? const <EventModel>[];

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: disabled ? null : () => onDateSelected(date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF2563EB)
                          : Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF1D4ED8)
                            : Colors.white.withValues(alpha: 0.96),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: disabled
                                ? const Color(0xFF94A3B8)
                                : (selected
                                      ? Colors.white
                                      : const Color(0xFF0F172A)),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (logos.isEmpty)
                          const SizedBox(height: 16)
                        else
                          _DayLogoStrip(events: logos, selected: selected),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _WeekLabel extends StatelessWidget {
  final String label;

  const _WeekLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _DayLogoStrip extends StatelessWidget {
  final List<EventModel> events;
  final bool selected;

  const _DayLogoStrip({required this.events, required this.selected});

  @override
  Widget build(BuildContext context) {
    final preview = events.take(2).toList();
    final remaining = events.length - preview.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < preview.length; i++)
          Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : -6),
            child: _DayLogoAvatar(
              event: preview[i],
              borderColor: selected
                  ? const Color(0xFF1D4ED8)
                  : const Color(0xFFFFFFFF),
            ),
          ),
        if (remaining > 0)
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? Colors.white.withValues(alpha: 0.2)
                  : const Color(0xFFE2E8F0),
              border: Border.all(
                color: selected ? const Color(0xFFBFDBFE) : Colors.white,
              ),
            ),
            child: Center(
              child: Text(
                '+$remaining',
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF475569),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayLogoAvatar extends StatelessWidget {
  final EventModel event;
  final Color borderColor;

  const _DayLogoAvatar({required this.event, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    final category = _inferVisualCategory(event);

    return Container(
      width: 16,
      height: 16,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: _eventCoverImage(
        event: event,
        fit: BoxFit.cover,
        fallback: ColoredBox(
          color: _categoryColor(category).withValues(alpha: 0.2),
          child: Center(
            child: Text(
              _categoryEmoji(category),
              style: const TextStyle(fontSize: 8),
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketsTab extends StatelessWidget {
  final String currentUserId;
  final String currentUserName;
  final RegistrationService registrationService;
  final EventService eventService;
  final ScrollController scrollController;

  const _TicketsTab({
    required this.currentUserId,
    required this.currentUserName,
    required this.registrationService,
    required this.eventService,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: registrationService.getMyRegistrations(userId: currentUserId),
        builder: (context, registrationSnapshot) {
          if (registrationSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final registrations = registrationSnapshot.data?.docs ?? [];

          return StreamBuilder<List<EventModel>>(
            stream: eventService.getEvents(),
            builder: (context, eventSnapshot) {
              final events = eventSnapshot.data ?? [];
              final eventById = {for (final event in events) event.id: event};

              return ListView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  _pageBottomPadding(context),
                ),
                children: [
                  Text(
                    'Biletlerim',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'QR kodunu açıp girişte okutabilirsin.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (registrations.isEmpty)
                    const _EmptyDiscoverCard(
                      title: 'Henüz biletin yok',
                      subtitle:
                          'Bir etkinliğe katıldığında biletlerin burada listelenecek.',
                    )
                  else
                    ...registrations.map((registrationDoc) {
                      final data = registrationDoc.data();
                      final eventId = (data['eventId'] ?? '').toString();
                      final checkedIn = data['checkedIn'] == true;
                      final event = eventById[eventId];
                      final ticketCategory = event != null
                          ? _inferVisualCategory(event)
                          : 'genel';

                      final eventTitle = event?.title ?? 'Etkinlik';
                      final eventDate = event != null
                          ? _displayEventDate(event)
                          : 'Tarih yakında';
                      final eventLocation = event?.location ?? 'Konum yakında';

                      final ticketOwnerName = currentUserName.trim().isNotEmpty
                          ? currentUserName
                          : (data['userName'] ?? 'Kullanıcı').toString();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.84),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  event != null
                                      ? _eventCoverImage(
                                          event: event,
                                          fit: BoxFit.cover,
                                          fallback: Container(
                                            color: const Color(0xFFE2E8F0),
                                            alignment: Alignment.center,
                                            child: Text(
                                              _categoryEmoji(ticketCategory),
                                              style: const TextStyle(
                                                fontSize: 24,
                                              ),
                                            ),
                                          ),
                                        )
                                      : _categoryAssetImage(
                                          category: 'genel',
                                          seed: 'ticket-fallback',
                                          fit: BoxFit.cover,
                                          fallback: Container(
                                            color: const Color(0xFFE2E8F0),
                                            alignment: Alignment.center,
                                            child: Text(
                                              _categoryEmoji('genel'),
                                              style: const TextStyle(
                                                fontSize: 24,
                                              ),
                                            ),
                                          ),
                                        ),
                                  Positioned(
                                    right: 4,
                                    bottom: 4,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: checkedIn
                                            ? const Color(0xFF475569)
                                            : const Color(0xFF2563EB),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        checkedIn
                                            ? Icons.check_rounded
                                            : Icons.qr_code_2_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    eventTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '$eventDate • $eventLocation',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: checkedIn
                                        ? null
                                        : () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => QrTicketScreen(
                                                  eventId: eventId,
                                                  eventTitle: eventTitle,
                                                  userId: currentUserId,
                                                  userName: ticketOwnerName,
                                                ),
                                              ),
                                            );
                                          },
                                    icon: Icon(
                                      checkedIn
                                          ? Icons.verified_rounded
                                          : Icons.qr_code_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      checkedIn
                                          ? 'Okutuldu'
                                          : 'Bileti Görüntüle',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: checkedIn
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFF2563EB),
                                      side: BorderSide(
                                        color: checkedIn
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final String fullName;
  final String email;
  final String phone;
  final bool phoneVerified;
  final String faculty;
  final String department;
  final String userType;
  final String grade;
  final String role;
  final ScrollController scrollController;
  final VoidCallback onVerifyPhone;
  final VoidCallback onLogout;

  const _ProfileTab({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.phoneVerified,
    required this.faculty,
    required this.department,
    required this.userType,
    required this.grade,
    required this.role,
    required this.scrollController,
    required this.onVerifyPhone,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(16, 16, 16, _pageBottomPadding(context)),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Text(
                    _initials(fullName),
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName.isEmpty ? 'Kullanıcı' : fullName,
                        style: textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _InfoCard(label: 'Rol', value: role),
          _InfoCard(label: 'Telefon', value: phone),
          _InfoCard(
            label: 'Telefon Doğrulama',
            value: phoneVerified ? 'Doğrulandı' : 'Doğrulanmadı',
          ),
          _InfoCard(label: 'Fakülte', value: faculty),
          _InfoCard(label: 'Bölüm', value: department),
          _InfoCard(label: 'Kullanıcı Türü', value: userType),
          _InfoCard(label: 'Sınıf', value: grade),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: onVerifyPhone,
            icon: Icon(
              phoneVerified
                  ? Icons.verified_user_rounded
                  : Icons.verified_user_outlined,
            ),
            label: Text(
              phoneVerified ? 'Numarayı Güncelle' : 'Numaramı Doğrula',
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Çıkış Yap'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;

  const _InfoCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.95)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value.isEmpty ? '-' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RetryNetworkImage extends StatefulWidget {
  final List<String> urls;
  final BoxFit fit;
  final Widget fallback;

  const _RetryNetworkImage({
    required this.urls,
    required this.fit,
    required this.fallback,
  });

  @override
  State<_RetryNetworkImage> createState() => _RetryNetworkImageState();
}

class _RetryNetworkImageState extends State<_RetryNetworkImage> {
  late List<String> _urls;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _initializeUrls();
  }

  @override
  void didUpdateWidget(covariant _RetryNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.urls.join('|') != widget.urls.join('|')) {
      _initializeUrls();
      _index = 0;
    }
  }

  void _initializeUrls() {
    final seen = <String>{};
    _urls = <String>[
      for (final raw in widget.urls)
        if (raw.trim().isNotEmpty && seen.add(raw.trim())) raw.trim(),
    ];
  }

  void _switchToNextUrl() {
    if (_index + 1 >= _urls.length) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _index + 1 >= _urls.length) {
        return;
      }
      setState(() => _index += 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_urls.isEmpty) {
      return widget.fallback;
    }

    return Image.network(
      _urls[_index],
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        _switchToNextUrl();
        return widget.fallback;
      },
    );
  }
}

String _normalizeCategory(String code) {
  final value = code.trim().toLowerCase();
  return value.isEmpty ? 'genel' : value;
}

const Map<String, List<String>> _categoryImagePools = {
  'konser': ['assets/images/categories/konser.jpg'],
  'tiyatro': ['assets/images/categories/tiyatro.jpg'],
  'spor': ['assets/images/categories/spor.jpg'],
  'sanat': ['assets/images/categories/sanat.jpg'],
  'yemek': ['assets/images/categories/yemek.jpg'],
  'sinema': ['assets/images/categories/sinema.jpg'],
  'genel': ['assets/images/categories/genel.jpg'],
};

String _pickCategoryImage({required String category, required String seed}) {
  final normalized = _normalizeCategory(category);
  final pool = _categoryImagePools[normalized] ?? _categoryImagePools['genel']!;
  final fingerprint = seed.codeUnits.fold<int>(
    0,
    (total, code) => total + code,
  );
  return pool[fingerprint % pool.length];
}

String _inferVisualCategory(EventModel event) {
  final category = _normalizeCategory(event.category);
  if (category != 'genel') {
    return category;
  }

  final signal = _normalizeSearch(
    '${event.title} ${event.description} ${event.location}',
  );

  if (signal.contains('sinema') ||
      signal.contains('film') ||
      signal.contains('vizyon') ||
      signal.contains('movie')) {
    return 'sinema';
  }

  if (signal.contains('konser') || signal.contains('canli muzik')) {
    return 'konser';
  }
  if (signal.contains('tiyatro') || signal.contains('sahne')) {
    return 'tiyatro';
  }
  if (signal.contains('maraton') ||
      signal.contains('mac') ||
      signal.contains('turnuva')) {
    return 'spor';
  }
  if (signal.contains('sergi') ||
      signal.contains('galeri') ||
      signal.contains('atolye')) {
    return 'sanat';
  }
  if (signal.contains('food') ||
      signal.contains('yemek') ||
      signal.contains('tadim')) {
    return 'yemek';
  }

  return 'genel';
}

Widget _categoryAssetImage({
  required String category,
  required String seed,
  required BoxFit fit,
  required Widget fallback,
}) {
  return Image.asset(
    _pickCategoryImage(category: category, seed: seed),
    fit: fit,
    errorBuilder: (context, error, stackTrace) => fallback,
  );
}

Widget _eventCoverImage({
  required EventModel event,
  required BoxFit fit,
  required Widget fallback,
}) {
  final category = _inferVisualCategory(event);
  final asset = _categoryAssetImage(
    category: category,
    seed: '${event.id}_${event.title}',
    fit: fit,
    fallback: fallback,
  );

  final custom = event.imageUrl.trim();
  final isHttp = custom.startsWith('http://') || custom.startsWith('https://');
  if (custom.isEmpty || !isHttp) {
    return asset;
  }

  return _RetryNetworkImage(urls: [custom], fit: fit, fallback: asset);
}

DateTime? _eventDateForUi(EventModel event) {
  final parsed = _parseEventDate(event.date);
  if (parsed == null) {
    return null;
  }

  final category = _inferVisualCategory(event);

  // Kullanıcının talebine göre sinema örneklerinde 13 -> 14 göster.
  if (category == 'sinema' &&
      parsed.year == 2026 &&
      parsed.month == 3 &&
      parsed.day == 13) {
    return parsed.add(const Duration(days: 1));
  }

  return parsed;
}

String _displayEventDate(EventModel event) {
  final adjusted = _eventDateForUi(event);
  if (adjusted == null) {
    return event.date;
  }

  final original = _parseEventDate(event.date);
  if (original == null || _isSameDate(original, adjusted)) {
    return event.date;
  }

  final timeMatch = RegExp(r'(\d{1,2}[:.]\d{2})').firstMatch(event.date);
  final base = _formatDate(adjusted);
  if (timeMatch == null) {
    return base;
  }

  return '$base ${timeMatch.group(1)}';
}

DateTime? _parseEventDate(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return null;
  }

  DateTime? toDate(int year, int month, int day) {
    if (year <= 0 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }

    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  final numeric = RegExp(
    r'\b(\d{1,2})[./-](\d{1,2})[./-](\d{4})\b',
  ).firstMatch(value);
  if (numeric != null) {
    final day = int.tryParse(numeric.group(1)!);
    final month = int.tryParse(numeric.group(2)!);
    final year = int.tryParse(numeric.group(3)!);
    if (day != null && month != null && year != null) {
      return toDate(year, month, day);
    }
  }

  final ymd = RegExp(
    r'\b(\d{4})[./-](\d{1,2})[./-](\d{1,2})\b',
  ).firstMatch(value);
  if (ymd != null) {
    final year = int.tryParse(ymd.group(1)!);
    final month = int.tryParse(ymd.group(2)!);
    final day = int.tryParse(ymd.group(3)!);
    if (year != null && month != null && day != null) {
      return toDate(year, month, day);
    }
  }

  final normalized = _normalizeSearch(value);
  const months = <String, int>{
    'ocak': 1,
    'subat': 2,
    'mart': 3,
    'nisan': 4,
    'mayis': 5,
    'haziran': 6,
    'temmuz': 7,
    'agustos': 8,
    'eylul': 9,
    'ekim': 10,
    'kasim': 11,
    'aralik': 12,
  };

  final named = RegExp(
    r'\b(\d{1,2})\s+(ocak|subat|mart|nisan|mayis|haziran|temmuz|agustos|eylul|ekim|kasim|aralik)\s*(\d{4})?\b',
  ).firstMatch(normalized);

  if (named != null) {
    final day = int.tryParse(named.group(1)!);
    final month = months[named.group(2)!];
    final year = int.tryParse(named.group(3) ?? '') ?? DateTime.now().year;
    if (day != null && month != null) {
      return toDate(year, month, day);
    }
  }

  return null;
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _formatDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${date.year}';
}

String _dateKey(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  return '${normalized.year}-${normalized.month}-${normalized.day}';
}

String _monthLabelTr(DateTime date) {
  const monthNames = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  final month = date.month.clamp(1, 12).toInt();
  final index = month - 1;
  return '${monthNames[index]} ${date.year}';
}

String _normalizeSearch(String value) {
  var result = value.toLowerCase().trim();

  const replacements = {
    'ı': 'i',
    'i̇': 'i',
    'ş': 's',
    'ğ': 'g',
    'ü': 'u',
    'ö': 'o',
    'ç': 'c',
    'â': 'a',
    'î': 'i',
    'û': 'u',
  };

  replacements.forEach((key, replacement) {
    result = result.replaceAll(key, replacement);
  });

  return result.replaceAll(RegExp(r'\s+'), ' ');
}

String _initials(String fullName) {
  final trimmed = fullName.trim();
  if (trimmed.isEmpty) {
    return 'U';
  }

  final parts = trimmed.split(RegExp(r'\s+'));

  if (parts.length == 1) {
    return parts.first[0].toUpperCase();
  }

  return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
}

String _categoryLabel(String code) {
  final normalized = _normalizeCategory(code);

  switch (normalized) {
    case 'konser':
      return 'Konser';
    case 'sinema':
      return 'Sinema';
    case 'tiyatro':
      return 'Tiyatro';
    case 'spor':
      return 'Spor';
    case 'sanat':
      return 'Sanat';
    case 'yemek':
      return 'Yemek';
    case 'genel':
      return 'Genel';
    case 'tumu':
      return 'Tümü';
    default:
      return normalized[0].toUpperCase() + normalized.substring(1);
  }
}

String _categoryEmoji(String code) {
  switch (_normalizeCategory(code)) {
    case 'konser':
      return '🎵';
    case 'sinema':
      return '🎬';
    case 'tiyatro':
      return '🎭';
    case 'spor':
      return '🏃';
    case 'sanat':
      return '🎨';
    case 'yemek':
      return '🍽️';
    case 'genel':
      return '🎯';
    case 'tumu':
      return '✨';
    default:
      return '✨';
  }
}

Color _categoryColor(String code) {
  switch (_normalizeCategory(code)) {
    case 'konser':
      return const Color(0xFF7C3AED);
    case 'sinema':
      return const Color(0xFF334155);
    case 'tiyatro':
      return const Color(0xFFEA580C);
    case 'spor':
      return const Color(0xFF0EA5E9);
    case 'sanat':
      return const Color(0xFFDB2777);
    case 'yemek':
      return const Color(0xFF16A34A);
    case 'genel':
      return const Color(0xFF2563EB);
    default:
      return const Color(0xFF2563EB);
  }
}

List<Color> _categoryGradient(String code) {
  switch (_normalizeCategory(code)) {
    case 'konser':
      return const [Color(0xFF6D28D9), Color(0xFFA21CAF)];
    case 'sinema':
      return const [Color(0xFF111827), Color(0xFF334155)];
    case 'tiyatro':
      return const [Color(0xFFDC2626), Color(0xFFF97316)];
    case 'spor':
      return const [Color(0xFF0284C7), Color(0xFF2563EB)];
    case 'sanat':
      return const [Color(0xFF9333EA), Color(0xFFDB2777)];
    case 'yemek':
      return const [Color(0xFF15803D), Color(0xFF16A34A)];
    case 'genel':
      return const [Color(0xFF2563EB), Color(0xFF0EA5E9)];
    default:
      return const [Color(0xFF2563EB), Color(0xFF0EA5E9)];
  }
}
