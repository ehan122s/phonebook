import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onChanged;

  const BottomNav({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  Widget _item(BuildContext context, int index, IconData icon, String label) {
    final active = selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
    final inactiveColor = isDark ? Colors.white60 : Colors.grey.shade600;

    return Expanded(
      child: InkWell(
        onTap: () => onChanged(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 23,
                color: active ? activeColor : inactiveColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: active ? activeColor : inactiveColor,
                  fontWeight:
                      active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBg = isDark ? const Color(0xFF18221B) : const Color(0xFFF1F3EA);
    final activeGreen = isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
    final inactiveCenterBg = isDark ? const Color(0xFF26352B) : const Color(0xFFDCE8D8);

    return Container(
      color: barBg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 5),
          child: Row(
            children: [
              _item(context, 1, Icons.description_outlined, 'Laporan'),
              _item(context, 2, Icons.calendar_month_outlined, 'Jadwal'),

              Expanded(
                child: Center(
                  child: InkWell(
                    onTap: () => onChanged(0),
                    customBorder: const CircleBorder(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: selectedIndex == 0
                            ? activeGreen
                            : inactiveCenterBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.home_rounded,
                        size: 27,
                        color: selectedIndex == 0
                            ? (isDark ? const Color(0xFF121814) : Colors.white)
                            : activeGreen,
                      ),
                    ),
                  ),
                ),
              ),

              _item(context, 3, Icons.menu_book_outlined, 'Materi'),
              _item(context, 4, Icons.person_outline_rounded, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }
}
