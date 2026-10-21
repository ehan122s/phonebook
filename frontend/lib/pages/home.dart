
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

  void changePage(int index) {
    if (index < 0 || index > 4) return;

    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardPage(onNavigate: changePage),
      const LaporanPage(),
      const JadwalPage(),
      const MateriPage(),
      const ProfilPage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: Stack(
        fit: StackFit.expand,
        children: [
          IndexedStack(
            index: selectedIndex,
            sizing: StackFit.expand,
            children: pages,
          ),
          const LogoutButton(),
        ],
      ),
      bottomNavigationBar: BottomNav(
        selectedIndex: selectedIndex,
        onChanged: changePage,
      ),
    );
  }
}