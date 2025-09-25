import 'package:flutter/material.dart';
import '../widgets/top_menu.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const Color darkGreen = Color(0xFF064E3B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkGreen,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Ténicos'),
        actions: const [TopMenu()],
      ),
      body: const SafeArea(
        child: Center(
          child: Text(
            'Mapa',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      ),
    );
  }
}
