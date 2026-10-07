import 'package:flutter/material.dart';
import 'pages/login.dart';

void main() {
  runApp(const PhonebookApp());
}

class PhonebookApp extends StatelessWidget {
  const PhonebookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phonebook',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: const Color(0xFFF8FAF8),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
        ),
      ),
      home: LoginPage(),
    );
  }
}