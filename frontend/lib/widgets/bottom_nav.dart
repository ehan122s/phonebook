import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BottomNav extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const BottomNav({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav>
    with SingleTickerProviderStateMixin {
  static const Cubic _liquidCurve = Cubic(0.22, 1.0, 0.36, 1.0);
  static const Duration _liquidDuration = Duration(milliseconds: 580);
  static const Duration _hoverDuration = Duration(milliseconds: 200);

  static const List<_BottomNavItem> _items = [
    _BottomNavItem(
      1,
      Icons.description_outlined,
      Icons.description_rounded,
      'Laporan',
    ),
    _BottomNavItem(
      2,
      Icons.calendar_month_outlined,
      Icons.calendar_month_rounded,
      'Jadwal',
    ),
    _BottomNavItem(
      0,
      Icons.home_outlined,
      Icons.home_rounded,
      'Beranda',
    ),
    _BottomNavItem(
      3,
      Icons.menu_book_outlined,
      Icons.menu_book_rounded,
      'Materi',
    ),
    _BottomNavItem(
      4,
      Icons.person_outline_rounded,
      Icons.person_rounded,
      'Profil',
    ),
  ];

  late final AnimationController _liquidCtrl;
  double _fromSlot = 2.0;
  double _toSlot = 2.0;
  int? _hoveredIndex;
  int? _pressedIndex;

  int _slotForIndex(int navIndex) {
    final idx = _items.indexWhere((item) => item.index == navIndex);
    return idx >= 0 ? idx : 2;
  }

  @override
  void initState() {
    super.initState();
    final initialSlot = _slotForIndex(widget.selectedIndex).toDouble();
    _fromSlot = initialSlot;
    _toSlot = initialSlot;

    _liquidCtrl = AnimationController(
      vsync: this,
      duration: _liquidDuration,
      value: 1.0,
    );
  }

  @override
  void didUpdateWidget(covariant BottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      final currentT = _liquidCurve.transform(_liquidCtrl.value);
      _fromSlot = lerpDouble(_fromSlot, _toSlot, currentT) ?? _toSlot;
      _toSlot = _slotForIndex(widget.selectedIndex).toDouble();
      _liquidCtrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _liquidCtrl.dispose();
    super.dispose();
  }

  void _handleTap(int index) {
    HapticFeedback.selectionClick();
    widget.onChanged(index);
  }

  Widget _buildNavItem(
    BuildContext context,
    _BottomNavItem item,
    bool isDark,
  ) {
    final bool active = widget.selectedIndex == item.index;
    final bool hovered = _hoveredIndex == item.index;
    final bool pressed = _pressedIndex == item.index;

    final Color activeColor = isDark
        ? const Color(0xFFA5D6A7)
        : const Color(0xFF1B4D20);
    final Color inactiveColor = isDark
        ? Colors.white.withValues(alpha: hovered ? 0.92 : 0.64)
        : const Color(0xFF4A554B).withValues(alpha: hovered ? 0.95 : 0.72);

    final Color itemColor = active ? activeColor : inactiveColor;
    final double targetScale = pressed
        ? 0.91
        : (active ? 1.04 : (hovered ? 1.03 : 1.0));

    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: item.label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hoveredIndex = item.index),
          onExit: (_) => setState(() {
            if (_hoveredIndex == item.index) _hoveredIndex = null;
          }),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressedIndex = item.index),
            onTapUp: (_) {
              if (_pressedIndex == item.index) {
                setState(() => _pressedIndex = null);
              }
              _handleTap(item.index);
            },
            onTapCancel: () {
              if (_pressedIndex == item.index) {
                setState(() => _pressedIndex = null);
              }
            },
            child: AnimatedContainer(
              duration: _hoverDuration,
              curve: _liquidCurve,
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                color: hovered && !active
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFF285C2E).withValues(alpha: 0.05))
                    : Colors.transparent,
              ),
              child: AnimatedScale(
                scale: targetScale,
                duration: _hoverDuration,
                curve: _liquidCurve,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSlide(
                      duration: const Duration(milliseconds: 480),
                      curve: _liquidCurve,
                      offset: Offset(0, active ? -0.06 : 0.0),
                      child: SizedBox(
                        height: 24,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: _liquidCurve,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, anim) {
                            return FadeTransition(
                              opacity: anim,
                              child: ScaleTransition(
                                scale: Tween<double>(
                                  begin: 0.84,
                                  end: 1.0,
                                ).animate(anim),
                                child: child,
                              ),
                            );
                          },
                          child: Icon(
                            active ? item.activeIcon : item.icon,
                            key: ValueKey<String>(
                              'nav_icon_${item.index}_$active',
                            ),
                            size: active ? 23.5 : 22.0,
                            color: itemColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 480),
                      curve: _liquidCurve,
                      style: TextStyle(
                        fontFamily: 'Arial',
                        fontSize: active ? 10.5 : 10.0,
                        color: itemColor,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: active ? 0.2 : 0.0,
                      ),
                      child: Text(
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: 88,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double totalWidth = constraints.maxWidth;
                  final double slotWidth = totalWidth / _items.length;

                  return Container(
                    height: 68,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.38 : 0.10,
                          ),
                          blurRadius: 28,
                          spreadRadius: 1,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: const Color(0xFF285C2E).withValues(
                            alpha: isDark ? 0.14 : 0.06,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(36),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDark
                                  ? [
                                      const Color(0xFF243329)
                                          .withValues(alpha: 0.78),
                                      const Color(0xFF162019)
                                          .withValues(alpha: 0.68),
                                    ]
                                  : [
                                      Colors.white.withValues(alpha: 0.82),
                                      const Color(0xFFEAF3EB)
                                          .withValues(alpha: 0.72),
                                    ],
                            ),
                            border: Border.all(
                              width: 1.15,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.14)
                                  : Colors.white.withValues(alpha: 0.78),
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              // Specular Top Glass Reflection (Efek kilau kaca Apple)
                              Positioned(
                                top: 0,
                                left: 24,
                                right: 24,
                                height: 1,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.0),
                                        Colors.white.withValues(
                                          alpha: isDark ? 0.26 : 0.85,
                                        ),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Liquid Glass Active Indicator (Fluid Stretch & Squash)
                              AnimatedBuilder(
                                animation: _liquidCtrl,
                                builder: (context, _) {
                                  final double rawT = _liquidCtrl.value;
                                  final double curvedT =
                                      _liquidCurve.transform(rawT);

                                  // Kurva kecepatan terpisah untuk tepi depan (leading) & tepi belakang (trailing)
                                  // Menciptakan efek tetesan cairan yang memanjang lalu menyatu
                                  final double fastT = const Cubic(
                                    0.12,
                                    1.0,
                                    0.28,
                                    1.0,
                                  ).transform(rawT);
                                  final double slowT = const Cubic(
                                    0.38,
                                    0.0,
                                    0.22,
                                    1.0,
                                  ).transform(rawT);

                                  final bool movingRight =
                                      _toSlot >= _fromSlot;
                                  final double leftSlot = movingRight
                                      ? (lerpDouble(
                                              _fromSlot, _toSlot, slowT) ??
                                          _toSlot)
                                      : (lerpDouble(
                                              _fromSlot, _toSlot, fastT) ??
                                          _toSlot);
                                  final double rightSlot = movingRight
                                      ? (lerpDouble(
                                              _fromSlot, _toSlot, fastT) ??
                                          _toSlot)
                                      : (lerpDouble(
                                              _fromSlot, _toSlot, slowT) ??
                                          _toSlot);

                                  const double horizontalPad = 5.0;
                                  final double pillLeft =
                                      (leftSlot * slotWidth) + horizontalPad;
                                  final double pillRight =
                                      ((rightSlot + 1.0) * slotWidth) -
                                          horizontalPad;
                                  final double pillWidth = (pillRight -
                                          pillLeft)
                                      .clamp(
                                        slotWidth - (horizontalPad * 2),
                                        totalWidth,
                                      );

                                  // Squash vertikal lembut saat kapsul sedang meregang (viscosity effect)
                                  final double stretchRatio =
                                      ((rightSlot - leftSlot).abs()).clamp(
                                    0.0,
                                    2.5,
                                  );
                                  final double pillHeight =
                                      (54.0 - (stretchRatio * 3.2))
                                          .clamp(46.0, 54.0);
                                  final double topOffset =
                                      (68.0 - pillHeight) / 2.0;

                                  // Kilau dinamis saat bergerak
                                  final double motionGlow =
                                      (1.0 - (2.0 * curvedT - 1.0).abs())
                                          .clamp(0.0, 1.0);

                                  return Positioned(
                                    left: pillLeft,
                                    top: topOffset,
                                    width: pillWidth,
                                    height: pillHeight,
                                    child: IgnorePointer(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(28),
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: isDark
                                                ? [
                                                    const Color(0xFF3B6E43)
                                                        .withValues(
                                                      alpha: 0.62 +
                                                          (motionGlow * 0.12),
                                                    ),
                                                    const Color(0xFF25492B)
                                                        .withValues(
                                                      alpha: 0.45 +
                                                          (motionGlow * 0.10),
                                                    ),
                                                  ]
                                                : [
                                                    Colors.white.withValues(
                                                      alpha: 0.94,
                                                    ),
                                                    const Color(0xFFDDF0DF)
                                                        .withValues(
                                                      alpha: 0.86,
                                                    ),
                                                  ],
                                          ),
                                          border: Border.all(
                                            width: 1.1,
                                            color: isDark
                                                ? const Color(0xFFA5D6A7)
                                                    .withValues(
                                                    alpha: 0.36 +
                                                        (motionGlow * 0.18),
                                                  )
                                                : Colors.white
                                                    .withValues(alpha: 0.95),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF285C2E)
                                                  .withValues(
                                                alpha: isDark ? 0.32 : 0.15,
                                              ),
                                              blurRadius:
                                                  16 + (motionGlow * 6),
                                              offset: const Offset(0, 4),
                                            ),
                                            if (!isDark)
                                              BoxShadow(
                                                color: Colors.white
                                                    .withValues(alpha: 0.8),
                                                blurRadius: 6,
                                                spreadRadius: -1,
                                                offset: const Offset(0, -1),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),

                              // Barisan Tombol Menu
                              Positioned.fill(
                                child: Row(
                                  children: _items
                                      .map(
                                        (item) => _buildNavItem(
                                          context,
                                          item,
                                          isDark,
                                        ),
                                      )
                                      .toList(),
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
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem {
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _BottomNavItem(
    this.index,
    this.icon,
    this.activeIcon,
    this.label,
  );
}