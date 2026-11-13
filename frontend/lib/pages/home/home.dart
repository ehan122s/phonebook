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
  bool _isAnimating = false;
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

    // PENTING: Hanya bersihkan _previousIndex saat animasi benar-benar COMPLETED
    // (Jangan pada AnimationStatus.dismissed karena forward(from: 0.0) memicu dismissed di awal!)
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

    // Pastikan widget halaman tujuan sudah dibuat di cache sebelum animasi dimulai
    _pageAt(index);

    final int oldIndex = selectedIndex;
    // Jika pengguna berpindah ke menu dengan indeks lebih besar -> halaman baru masuk dari kanan (+1)
    // Jika pengguna berpindah ke menu dengan indeks lebih kecil -> halaman baru masuk dari kiri (-1)
    final int direction = index > oldIndex ? 1 : -1;

    _transitionCtrl.stop();

    setState(() {
      _slideDirection = direction;
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
                final bool activeTransition =
                    _isAnimating && _previousIndex != null && _previousIndex != selectedIndex;
                final double progress = _curvedAnim.value;

                return Stack(
                  fit: StackFit.expand,
                  children: List<Widget>.generate(_pages.length, (index) {
                    final page = _pages[index];
                    if (page == null && index != selectedIndex) {
                      return const SizedBox.shrink();
                    }

                    final resolvedPage = _pageAt(index);
                    final bool isCurrent = index == selectedIndex;
                    final bool isPrevious = activeTransition && index == _previousIndex;
                    final bool isVisible = isCurrent || isPrevious;

                    Offset offset = Offset.zero;
                    if (activeTransition) {
                      if (isCurrent) {
                        // Halaman baru masuk dari kanan (+1 -> 0) atau dari kiri (-1 -> 0)
                        offset = Offset(
                          _slideDirection * (1.0 - progress),
                          0.0,
                        );
                      } else if (isPrevious) {
                        // Halaman sebelumnya bergeser ke kiri (0 -> -1) atau ke kanan (0 -> +1)
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
          height: 88 + MediaQuery.paddingOf(context).bottom,
          child: BottomNav(
            selectedIndex: selectedIndex,
            onChanged: changePage,
          ),
        ),
      ),
    );
  }
}
