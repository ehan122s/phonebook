import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onChanged;

  const BottomNav({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade200,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        10,
        8,
        10,
        10,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _item(
              0,
              Icons.home_rounded,
              'Beranda',
            ),
            _item(
              1,
              Icons.description_outlined,
              'Laporan',
            ),
            _item(
              2,
              Icons.calendar_month_outlined,
              'Jadwal',
            ),
            _item(
              3,
              Icons.menu_book_outlined,
              'Materi',
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    int index,
    IconData icon,
    String label,
  ) {
    final active = selectedIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => onChanged(index),
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFFEAF7ED)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              AnimatedScale(
                scale: active ? 1.12 : 1,
                duration: const Duration(milliseconds: 220),
                child: Icon(
                  icon,
                  size: 25,
                  color: active
                      ? const Color(0xFF2E7D32)
                      : Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: active
                      ? const Color(0xFF2E7D32)
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}