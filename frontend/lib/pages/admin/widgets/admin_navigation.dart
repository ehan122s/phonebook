import 'package:flutter/material.dart';

import '../admin_theme.dart';

class AdminSidebar extends StatelessWidget {
  final int selectedMenu;
  final int usersCount;
  final bool isDrawer;
  final ValueChanged<int> onSelectMenu;
  final VoidCallback onLogout;

  const AdminSidebar({
    super.key,
    required this.selectedMenu,
    required this.usersCount,
    required this.isDrawer,
    required this.onSelectMenu,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final t = AdminTheme.of(context);
    final menuItems = [
      (icon: Icons.dashboard_rounded, label: 'Beranda Admin', badge: null),
      (
        icon: Icons.people_alt_rounded,
        label: 'Kelola Pengguna',
        badge: '$usersCount',
      ),
      (
        icon: Icons.folder_shared_rounded,
        label: 'Folder Seluruh User',
        badge: null,
      ),
      (icon: Icons.description_rounded, label: 'Laporan Kegiatan', badge: null),
      (
        icon: Icons.bar_chart_rounded,
        label: 'Monitoring Aktivitas',
        badge: null,
      ),
      (icon: Icons.menu_book_rounded, label: 'Materi Penyuluhan', badge: null),
    ];

    return Container(
      decoration: BoxDecoration(
        color: t.surfaceBg,
        border: Border(right: BorderSide(color: t.borderColor, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B462B),
                  AdminTheme.kPrimary,
                  AdminTheme.kSecondary,
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AdminTheme.kPrimary.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.forest_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PHONEBOOK',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Panel Administrator',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'MENU NAVIGASI',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: t.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                final isSelected = selectedMenu == index;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        onSelectMenu(index);
                        if (isDrawer) Navigator.pop(context);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (t.isDark
                                    ? const Color(0xFF243B2B)
                                    : AdminTheme.kPrimary)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.icon,
                              size: 20,
                              color: isSelected
                                  ? Colors.white
                                  : t.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : t.textPrimary,
                                ),
                              ),
                            ),
                            if (item.badge != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.22)
                                      : t.lightGreenBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  item.badge!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : t.primaryAccent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onLogout,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: t.isDark
                    ? const Color(0xFF331E1E)
                    : const Color(0xFFFDECEA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFD32F2F).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.logout_rounded,
                    size: 19,
                    color: Color(0xFFD32F2F),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Keluar Panel Admin',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD32F2F),
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
}

class AdminMobileBottomNav extends StatelessWidget {
  final int selectedMenu;
  final ValueChanged<int> onSelectMenu;

  const AdminMobileBottomNav({
    super.key,
    required this.selectedMenu,
    required this.onSelectMenu,
  });

  @override
  Widget build(BuildContext context) {
    final t = AdminTheme.of(context);
    final barBg = t.isDark ? const Color(0xFF18221B) : const Color(0xFFF1F3EA);
    final activeGreen = t.isDark
        ? const Color(0xFF81C784)
        : const Color(0xFF2E7D32);
    final inactiveCenterBg = t.isDark
        ? const Color(0xFF26352B)
        : const Color(0xFFDCE8D8);
    final inactiveColor = t.isDark ? Colors.white60 : Colors.grey.shade600;

    Widget navItem(int menuIndex, IconData icon, String label) {
      final active = selectedMenu == menuIndex;
      return Expanded(
        child: InkWell(
          onTap: () => onSelectMenu(menuIndex),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: active ? activeGreen : inactiveColor,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: active ? activeGreen : inactiveColor,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: barBg,
        border: Border(top: BorderSide(color: t.borderColor, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 4),
          child: Row(
            children: [
              navItem(1, Icons.people_outline_rounded, 'Pengguna'),
              navItem(2, Icons.folder_shared_outlined, 'Folder'),
              Expanded(
                child: Center(
                  child: InkWell(
                    onTap: () => onSelectMenu(0),
                    customBorder: const CircleBorder(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: selectedMenu == 0
                            ? activeGreen
                            : inactiveCenterBg,
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (selectedMenu == 0)
                            BoxShadow(
                              color: activeGreen.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                        ],
                      ),
                      child: Icon(
                        Icons.home_rounded,
                        size: 26,
                        color: selectedMenu == 0
                            ? (t.isDark
                                  ? const Color(0xFF121814)
                                  : Colors.white)
                            : activeGreen,
                      ),
                    ),
                  ),
                ),
              ),
              navItem(3, Icons.description_outlined, 'Laporan'),
              navItem(4, Icons.bar_chart_rounded, 'Monitoring'),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminTopProfileHeader extends StatelessWidget {
  final bool isWideScreen;
  final int selectedMenu;
  final String title;
  final String adminName;
  final bool isSyncing;
  final VoidCallback onBackHome;
  final VoidCallback onRefresh;

  const AdminTopProfileHeader({
    super.key,
    required this.isWideScreen,
    required this.selectedMenu,
    required this.title,
    required this.adminName,
    required this.isSyncing,
    required this.onBackHome,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final t = AdminTheme.of(context);
    return SafeArea(
      bottom: false,
      child: Container(
        height: 64,
        padding: EdgeInsets.symmetric(horizontal: isWideScreen ? 26 : 14),
        decoration: BoxDecoration(
          color: t.cardBg,
          border: Border(bottom: BorderSide(color: t.borderColor, width: 1)),
        ),
        child: Row(
          children: [
            if (!isWideScreen) ...[
              Builder(
                builder: (ctx) => IconButton(
                  tooltip: 'Buka Menu Navigasi',
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                  icon: Icon(Icons.menu_rounded, color: t.textPrimary),
                ),
              ),
              if (selectedMenu != 0)
                IconButton(
                  tooltip: 'Kembali ke Beranda Admin',
                  onPressed: onBackHome,
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: t.primaryAccent,
                    size: 22,
                  ),
                ),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: t.textPrimary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Segarkan Data',
              onPressed: isSyncing ? null : onRefresh,
              icon: isSyncing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.primaryAccent,
                      ),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      color: t.primaryAccent,
                      size: 22,
                    ),
            ),
            if (isWideScreen) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: t.softGreenBg,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: t.borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AdminTheme.kPrimary,
                      child: Text(
                        adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      adminName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
