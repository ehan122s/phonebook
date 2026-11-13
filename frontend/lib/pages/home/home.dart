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
  int selectedIndex = 0;
  int? _previousIndex;
  int _slideDirection = 1; // 1 = halaman baru masuk dari kanan, -1 = masuk dari kiri
  final List<int> _tabHistory = [0];

  late final List<Widget?> _pages;
  late final AnimationController _transitionCtrl;
  late final Animation<double> _curvedAnim;

  @override
  void initState() {
    super.initState();
    _pages = List<Widget?>.filled(5, null);
    _pages[0] = DashboardPage(onNavigate: changePage);

    // Revisi Animasi Bottom Navigation Bar:
    // Durasi 400ms (0,4 detik) dengan kurva Curves.easeInOutCubic
    _transitionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _curvedAnim = CurvedAnimation(
      parent: _transitionCtrl,
      curve: Curves.easeInOutCubic,
    );

    _transitionCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        if (mounted && _previousIndex != null) {
          setState(() {
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

    // Pastikan widget halaman tujuan sudah dibuat di cache sebelum animasi dimulai
    _pageAt(index);

    setState(() {
      // Jika berpindah ke menu dengan indeks lebih besar -> halaman baru masuk dari kanan (+1)
      // Jika berpindah ke menu dengan indeks lebih kecil -> halaman baru masuk dari kiri (-1)
      _slideDirection = index > selectedIndex ? 1 : -1;
      _previousIndex = selectedIndex;
      selectedIndex = index;

      if (recordHistory) {
        if (_tabHistory.isEmpty || _tabHistory.last != index) {
          _tabHistory.add(index);
        }
      }
    });

    _transitionCtrl.forward(from: 0.0);
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
        body: ColoredBox(
          color: bgColor,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _curvedAnim,
              builder: (context, _) {
                final isAnimating =
                    _transitionCtrl.isAnimating && _previousIndex != null;
                final progress = _curvedAnim.value;

                return Stack(
                  fit: StackFit.expand,
                  children: List<Widget>.generate(_pages.length, (index) {
                    final page = _pages[index];
                    if (page == null && index != selectedIndex) {
                      return const SizedBox.shrink();
                    }

                    final resolvedPage = _pageAt(index);
                    final isCurrent = index == selectedIndex;
                    final isPrevious = isAnimating && index == _previousIndex;
                    final isVisible = isCurrent || isPrevious;

                    Offset offset = Offset.zero;
                    if (isAnimating) {
                      if (isCurrent) {
                        // Halaman baru masuk dari kanan (jika _slideDirection == 1)
                        // atau masuk dari kiri (jika _slideDirection == -1)
                        offset = Offset(
                          _slideDirection * (1.0 - progress),
                          0.0,
                        );
                      } else if (isPrevious) {
                        // Halaman lama bergeser keluar ke arah berlawanan
                        offset = Offset(
                          -_slideDirection * progress,
                          0.0,
                        );
                      }
                    }

                    // Pertahankan state seluruh halaman yang sudah dibuka dengan Offstage + TickerMode + RepaintBoundary
                    return Offstage(
                      key: ValueKey<String>('home_tab_slot_$index'),
                      offstage: !isVisible,
                      child: TickerMode(
                        enabled: isVisible,
                        child: FractionalTranslation(
                          translation: offset,
                          child: RepaintBoundary(
                            child: ColoredBox(
                              color: bgColor,
                              child: resolvedPage,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ),
        bottomNavigationBar: SizedBox(
          height: 72 + MediaQuery.paddingOf(context).bottom,
          child: BottomNav(
            selectedIndex: selectedIndex,
            onChanged: changePage,
          ),
        ),
      ),
    );
  }
}