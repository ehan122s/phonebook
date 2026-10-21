
import 'package:flutter/material.dart';

import 'dashboard.dart';
import 'laporan.dart';
import 'jadwal.dart';
import 'materi.dart';
import 'profil.dart';

import '../widgets/bottom_nav.dart';
import '../widgets/logout_button.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;
  late final List<Widget?> _pages;

  @override
  void initState() {
    super.initState();
    _pages = List<Widget?>.filled(5, null);
    _pages[0] = DashboardPage(onNavigate: changePage);
  }

  Widget _pageAt(int index) {
    final cachedPage = _pages[index];
    if (cachedPage != null) return cachedPage;

    final page = switch (index) {
      1 => const LaporanPage(),
      2 => const JadwalPage(),
      3 => const MateriPage(),
      4 => const ProfilPage(),
      _ => throw RangeError.index(index, _pages, 'index'),
    };
    _pages[index] = page;
    return page;
  }

  void changePage(int index) {
    if (index < 0 || index > 4) return;

    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: Stack(
        fit: StackFit.expand,
        children: [
          IndexedStack(
            index: selectedIndex,
            sizing: StackFit.expand,
            children: List<Widget>.generate(
              _pages.length,
              (index) => index == selectedIndex || _pages[index] != null
                  ? _pageAt(index)
                  : const SizedBox.shrink(),
            ),
          ),
          const Positioned(
            top: 12,
            right: 12,
            child: SafeArea(
              child: LogoutButton(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SizedBox(
        height: 72 + MediaQuery.paddingOf(context).bottom,
        child: BottomNav(
          selectedIndex: selectedIndex,
          onChanged: changePage,
        ),
      ),
    );
  }
}