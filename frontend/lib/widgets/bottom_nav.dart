import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  static const _duration = Duration(milliseconds: 400);
  static const _items = [
    _BottomNavItem(1, Icons.description_outlined, 'Laporan'),
    _BottomNavItem(2, Icons.calendar_month_outlined, 'Jadwal'),
    _BottomNavItem(0, Icons.home_rounded, ''),
    _BottomNavItem(3, Icons.menu_book_outlined, 'Materi'),
    _BottomNavItem(4, Icons.person_outline_rounded, 'Profil'),
  ];

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const BottomNav({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  Widget _item(BuildContext context, _BottomNavItem item) {
    final active = selectedIndex == item.index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = active
        ? (isDark ? const Color(0xFF81C784) : const Color(0xFF285C2E))
        : (isDark ? Colors.white60 : const Color(0xFF777D76));

    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: item.label.isEmpty ? 'Beranda' : item.label,
        child: InkWell(
          onTap: () => onChanged(item.index),
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(2, 20, 2, 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: 24,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: active
                        ? SizedBox(
                            key: ValueKey<String>('active-${item.index}'),
                            width: 24,
                            height: 24,
                          )
                        : Icon(
                            item.icon,
                            key: ValueKey<String>('icon-${item.index}'),
                            size: 23,
                            color: color,
                          ),
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: _duration,
                  curve: Curves.easeInOutCubic,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: item.label.isEmpty
                      ? const SizedBox(height: 13)
                      : Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedItem = _items.firstWhere(
      (item) => item.index == selectedIndex,
    );
    final selectedPosition = _items.indexOf(selectedItem);
    final pillColor = isDark
        ? const Color(0xFF202C24)
        : const Color(0xFFEAF1E9);

    return SafeArea(
      top: false,
      child: SizedBox(
        height: 88,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 7),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: pillColor,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.18 : 0.08,
                        ),
                        blurRadius: 18,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedAlign(
                    alignment: Alignment(-0.8 + selectedPosition * 0.4, -1),
                    duration: _duration,
                    curve: Curves.easeInOutCubic,
                    child: Transform.translate(
                      offset: const Offset(0, -12),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF285C2E)
                                  .withValues(alpha: 0.18),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(
                          selectedItem.icon,
                          size: 24,
                          color: const Color(0xFF285C2E),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                  children: _items.map((item) => _item(context, item)).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem {
  final int index;
  final IconData icon;
  final String label;

  const _BottomNavItem(this.index, this.icon, this.label);
}
