import 'package:flutter/material.dart';

import 'dashboard.dart';
import 'laporan.dart';
import 'jadwal.dart';
import 'materi.dart';

import '../widgets/bottom_nav.dart';
import '../widgets/logout_button.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedIndex = 0;

  final List<Widget> pages = const [
    DashboardPage(),
    LaporanPage(),
    JadwalPage(),
    MateriPage(),
  ];

  void changePage(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: selectedIndex,
            children: pages,
          ),

          const LogoutButton(),

          Align(
            alignment: Alignment.bottomCenter,
            child: BottomNav(
              selectedIndex: selectedIndex,
              onChanged: changePage,
            ),
          ),
        ],
      ),
    );
  }
}