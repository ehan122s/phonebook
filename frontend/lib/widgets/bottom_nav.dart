
import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onChanged;

  const BottomNav({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  static const green = Color(0xFF2E7D32);

  Widget _item(int index, IconData icon, String label) {
    final active = selectedIndex == index;

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
                color: active ? green : Colors.grey.shade600,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: active ? green : Colors.grey.shade600,
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
    return Container(
      color: const Color(0xFFF1F3EA),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 5),
          child: Row(
            children: [
              _item(1, Icons.description_outlined, 'Laporan'),
              _item(2, Icons.calendar_month_outlined, 'Jadwal'),

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
                            ? green
                            : const Color(0xFFDCE8D8),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.home_rounded,
                        size: 27,
                        color: selectedIndex == 0
                            ? Colors.white
                            : green,
                      ),
                    ),
                  ),
                ),
              ),

              _item(3, Icons.menu_book_outlined, 'Materi'),
              _item(4, Icons.person_outline_rounded, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }
}