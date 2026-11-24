import 'package:flutter/material.dart';

import '../admin_theme.dart';
import '../widgets/admin_shared_widgets.dart';

class AdminUsersSection extends StatelessWidget {
  final bool isWideScreen;
  final List<Map<String, String>> allUsers;
  final List<Map<String, String>> filteredUsers;
  final String searchQuery;
  final String filterStatus;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onAddUser;
  final ValueChanged<Map<String, String>> onEditUser;
  final ValueChanged<Map<String, String>> onDeleteUser;
  final VoidCallback onOpenFolder;

  const AdminUsersSection({
    super.key,
    required this.isWideScreen,
    required this.allUsers,
    required this.filteredUsers,
    required this.searchQuery,
    required this.filterStatus,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onAddUser,
    required this.onEditUser,
    required this.onDeleteUser,
    required this.onOpenFolder,
  });

  @override
  Widget build(BuildContext context) {
    final t = AdminTheme.of(context);
    final activeCount = allUsers
        .where((u) => (u['status'] ?? 'Aktif') == 'Aktif')
        .length;
    final horizontalPad = isWideScreen ? 28.0 : 18.0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(horizontalPad, 20, horizontalPad, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
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
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AdminTheme.kPrimary.withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.people_alt_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manajemen Akun Penyuluh',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Kelola data pegawai, wilayah tugas, dan akses pelaporan lapangan.',
                            style: TextStyle(
                              color: Color(0xFFE8F2E8),
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    HeaderPillBadge(
                      icon: Icons.groups_rounded,
                      label: '${allUsers.length} Total Pegawai',
                    ),
                    HeaderPillBadge(
                      icon: Icons.check_circle_outline_rounded,
                      label: '$activeCount Status Aktif',
                    ),
                    HeaderPillBadge(
                      icon: Icons.folder_shared_outlined,
                      label: '${allUsers.length} Direktori Folder',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 600;
              final searchField = TextField(
                onChanged: onSearchChanged,
                style: TextStyle(color: t.textPrimary, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText:
                      'Cari nama penyuluh, NIP, email, atau wilayah tugas...',
                  hintStyle: TextStyle(fontSize: 13, color: t.textSecondary),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: t.primaryAccent,
                  ),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: () => onSearchChanged(''),
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: t.textSecondary,
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: t.cardBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: t.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: t.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: t.primaryAccent, width: 1.5),
                  ),
                ),
              );

              final addButton = ElevatedButton.icon(
                onPressed: onAddUser,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
                label: const Text(
                  'Tambah Pengguna',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.kPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchField,
                    const SizedBox(height: 10),
                    addButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 14),
                  addButton,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  [
                    'Semua',
                    'Aktif',
                    'Nonaktif',
                    'Penyuluh',
                    'Koordinator',
                    'Admin',
                  ].map((filter) {
                    final selected = filterStatus == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: selected,
                        showCheckmark: false,
                        selectedColor: AdminTheme.kPrimary,
                        backgroundColor: t.cardBg,
                        side: BorderSide(
                          color: selected ? AdminTheme.kPrimary : t.borderColor,
                        ),
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : t.textPrimary,
                        ),
                        onSelected: (_) => onFilterChanged(filter),
                      ),
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          if (filteredUsers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: t.borderColor),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.person_search_rounded,
                    size: 46,
                    color: t.textSecondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tidak ada data pengguna yang cocok dengan pencarian.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: t.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final useTableLayout = constraints.maxWidth >= 780;
                if (useTableLayout) {
                  return _buildDesktopUsersTable(t, filteredUsers);
                }
                return Column(
                  children: List.generate(
                    filteredUsers.length,
                    (index) => _buildMobileUserCard(t, filteredUsers[index]),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMobileUserCard(AdminTheme t, Map<String, String> u) {
    final name = u['name'] ?? '-';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.borderColor),
        boxShadow: [
          BoxShadow(
            color: AdminTheme.kPrimary.withValues(
              alpha: t.isDark ? 0.18 : 0.04,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: t.lightGreenBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: t.primaryAccent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'NIP: ${(u['nip'] ?? '').isEmpty ? '-' : u['nip']}',
                      style: TextStyle(fontSize: 12.5, color: t.textSecondary),
                    ),
                  ],
                ),
              ),
              AdminStatusChip(status: u['status'] ?? 'Aktif'),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: t.borderColor),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              UserMetaItem(
                icon: Icons.work_outline_rounded,
                text: u['role'] ?? 'Penyuluh',
                textColor: t.textPrimary,
                iconColor: t.primaryAccent,
              ),
              UserMetaItem(
                icon: Icons.location_on_outlined,
                text: u['wilayah'] ?? 'CDK Wilayah Garut',
                textColor: t.textSecondary,
                iconColor: AdminTheme.kSecondary,
              ),
              UserMetaItem(
                icon: Icons.email_outlined,
                text: u['email'] ?? '-',
                textColor: t.textSecondary,
                iconColor: t.primaryAccent,
              ),
              UserMetaItem(
                icon: Icons.phone_outlined,
                text: (u['whatsapp'] ?? '').isEmpty ? '-' : u['whatsapp']!,
                textColor: t.textSecondary,
                iconColor: AdminTheme.kSecondary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenFolder,
                  icon: Icon(
                    Icons.folder_shared_outlined,
                    size: 17,
                    color: t.primaryAccent,
                  ),
                  label: Text(
                    'Folder',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: t.primaryAccent,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: t.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onEditUser(u),
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 17,
                    color: AdminTheme.kSecondary,
                  ),
                  label: const Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AdminTheme.kSecondary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: t.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Hapus Pengguna',
                onPressed: () => onDeleteUser(u),
                style: IconButton.styleFrom(
                  backgroundColor: t.isDark
                      ? const Color(0xFF331E1E)
                      : const Color(0xFFFDECEA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 19,
                  color: Color(0xFFD32F2F),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopUsersTable(
    AdminTheme t,
    List<Map<String, String>> users,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.borderColor),
        boxShadow: [
          BoxShadow(
            color: AdminTheme.kPrimary.withValues(
              alpha: t.isDark ? 0.18 : 0.04,
            ),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: t.softGreenBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    'No',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: t.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Nama & NIP Penyuluh',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: t.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Email & WhatsApp',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: t.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Wilayah & Peran',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: t.textPrimary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 90,
                  child: Text(
                    'Status',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: t.textPrimary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 126,
                  child: Text(
                    'Aksi / Folder',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: t.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(users.length, (index) {
            final u = users[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: t.isDark
                    ? const Color(0xFF18211C)
                    : const Color(0xFFFAFBF9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.borderColor),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: t.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u['name'] ?? '-',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: t.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'NIP: ${(u['nip'] ?? '').isEmpty ? '-' : u['nip']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: t.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u['email'] ?? '-',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: t.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (u['whatsapp'] ?? '').isEmpty
                                ? '-'
                                : u['whatsapp']!,
                            style: TextStyle(
                              fontSize: 12,
                              color: t.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u['wilayah'] ?? '-',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: t.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            u['role'] ?? 'Penyuluh',
                            style: TextStyle(
                              fontSize: 12,
                              color: t.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: AdminStatusChip(status: u['status'] ?? 'Aktif'),
                  ),
                  SizedBox(
                    width: 126,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Buka Folder User Ini',
                          onPressed: onOpenFolder,
                          icon: Icon(
                            Icons.folder_shared_outlined,
                            size: 19,
                            color: t.primaryAccent,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Edit Pengguna',
                          onPressed: () => onEditUser(u),
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: AdminTheme.kSecondary,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Hapus Pengguna',
                          onPressed: () => onDeleteUser(u),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Color(0xFFD32F2F),
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
    );
  }
}
