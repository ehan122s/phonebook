import 'dart:ui';
import 'package:flutter/material.dart';

import '../dashboard/dashboard.dart';
import '../laporan/laporan.dart';
import '../jadwal/jadwal.dart';
import '../materi/materi.dart';
import '../profil/profil.dart';

import '../../widgets/bottom_nav.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  // Timing & Easing sesuai spesifikasi:
  // Total durasi: 420ms (Page exit selesai pada ~180ms pertama, Page enter berjalan mulus hingga 420ms)
  // Easing: cubic-bezier(0.22, 1, 0.36, 1)
  static const Duration _transitionDuration = Duration(milliseconds: 420);
  static const Cubic _smoothEasing = Cubic(0.22, 1.0, 0.36, 1.0);

  int selectedIndex = 0;
  int? _previousIndex;
  bool _isAnimating = false;
  final List<int> _tabHistory = [0];

  late final List<Widget?> _pages;
  late final AnimationController _transitionCtrl;
  late final Animation<double> _enterFadeAnim;
  late final Animation<double> _enterScaleAnim;
  late final Animation<double> _enterBlurAnim;
  late final Animation<double> _exitFadeAnim;
  late final Animation<double> _exitScaleAnim;

  @override
  void initState() {
    super.initState();
    _pages = List<Widget?>.filled(5, null);
    _pages[0] = DashboardPage(onNavigate: changePage);

    _transitionCtrl = AnimationController(
      vsync: this,
      duration: _transitionDuration,
    );

    // Page Exit: ~180ms (rasio 180 / 420 ≈ 0.43)
    _exitFadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _transitionCtrl,
        curve: const Interval(0.0, 0.43, curve: _smoothEasing),
      ),
    );

    _exitScaleAnim = Tween<double>(begin: 1.0, end: 0.985).animate(
      CurvedAnimation(
        parent: _transitionCtrl,
        curve: const Interval(0.0, 0.43, curve: _smoothEasing),
      ),
    );

    // Page Enter: 420ms (Smooth Fade + Scale 0.98 -> 1.0 + Subtle Blur-to-Clear)
    _enterFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _transitionCtrl,
        curve: const Interval(0.08, 1.0, curve: _smoothEasing),
      ),
    );

    _enterScaleAnim = Tween<double>(begin: 0.98, end: 1.0).animate(
      CurvedAnimation(
        parent: _transitionCtrl,
        curve: _smoothEasing,
      ),
    );

    _enterBlurAnim = Tween<double>(begin: 3.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _transitionCtrl,
        curve: const Interval(0.0, 0.75, curve: _smoothEasing),
      ),
    );

    // Hanya bersihkan _previousIndex saat animasi benar-benar COMPLETED
    _transitionCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _isAnimating = false;
            _previousIndex = null;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _transitionCtrl.dispose();
    super.dispose();
  }

  Widget _pageAt(int index) {
    final cachedPage = _pages[index];
    if (cachedPage != null) return cachedPage;

    final page = switch (index) {
      0 => DashboardPage(onNavigate: changePage),
      1 => const LaporanPage(),
      2 => JadwalPage(
          onBack: _handleChildBackNavigation,
          onNavigate: changePage,
        ),
      3 => const MateriPage(),
      4 => const ProfilPage(),
      _ => throw RangeError.index(index, _pages, 'index'),
    };
    _pages[index] = page;
    return page;
  }

  void _handleChildBackNavigation() {
    if (_tabHistory.length > 1) {
      _tabHistory.removeLast();
      final target = _tabHistory.last;
      changePage(target, recordHistory: false);
    } else if (selectedIndex != 0) {
      changePage(0);
    }
  }

  void changePage(int index, {bool recordHistory = true}) {
    if (index < 0 || index > 4 || index == selectedIndex) return;

    // Pastikan widget halaman tujuan sudah siap di cache sebelum transisi dimulai
    _pageAt(index);

    final int oldIndex = selectedIndex;
    _transitionCtrl.stop();

    setState(() {
      _previousIndex = oldIndex;
      selectedIndex = index;
      _isAnimating = true;

      if (recordHistory) {
        if (_tabHistory.isEmpty || _tabHistory.last != index) {
          _tabHistory.add(index);
        }
      }
    });

    _transitionCtrl.forward(from: 0.0);
  }

  Widget _buildTransitionedPage({
    required Widget child,
    required Color bgColor,
    required bool isCurrent,
    required bool isPrevious,
    required bool activeTransition,
  }) {
    Widget content = RepaintBoundary(
      child: ColoredBox(
        color: bgColor,
        child: child,
      ),
    );

    if (!activeTransition) {
      return content;
    }

    if (isCurrent) {
      final double sigma = _enterBlurAnim.value;
      if (sigma > 0.08) {
        content = ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: content,
        );
      }
      return Opacity(
        opacity: _enterFadeAnim.value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: _enterScaleAnim.value,
          alignment: Alignment.center,
          child: content,
        ),
      );
    }

    if (isPrevious) {
      return IgnorePointer(
        child: Opacity(
          opacity: _exitFadeAnim.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: _exitScaleAnim.value,
            alignment: Alignment.center,
            child: content,
          ),
        ),
      );
    }

    return content;
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return PopScope(
      canPop: selectedIndex == 0 && _tabHistory.length <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && selectedIndex != 0) {
          _handleChildBackNavigation();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        extendBody: true,
        body: ColoredBox(
          color: bgColor,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _transitionCtrl,
              builder: (context, _) {
                final bool activeTransition = _isAnimating &&
                    _previousIndex != null &&
                    _previousIndex != selectedIndex;

                return Stack(
                  fit: StackFit.expand,
                  children: List<Widget>.generate(_pages.length, (index) {
                    final page = _pages[index];
                    if (page == null && index != selectedIndex) {
                      return const SizedBox.shrink();
                    }

                    final resolvedPage = _pageAt(index);
                    final bool isCurrent = index == selectedIndex;
                    final bool isPrevious =
                        activeTransition && index == _previousIndex;
                    final bool isVisible = isCurrent || isPrevious;

                    return Offstage(
                      key: ValueKey<String>('home_tab_slot_$index'),
                      offstage: !isVisible,
                      child: TickerMode(
                        enabled: isVisible,
                        child: _buildTransitionedPage(
                          child: resolvedPage,
                          bgColor: bgColor,
                          isCurrent: isCurrent,
                          isPrevious: isPrevious,
                          activeTransition: activeTransition,
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),
        bottomNavigationBar: BottomNav(
          selectedIndex: selectedIndex,
          onChanged: changePage,
        ),
      ),
    );
  }
}