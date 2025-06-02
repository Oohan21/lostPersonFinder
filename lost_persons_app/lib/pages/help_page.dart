import 'package:flutter/material.dart';
import '../main.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MainScaffold(
      title: 'Help',
      body: const Center(child: Text('Help Page')),
    );
  }
}
