// Estrutura organizada com navegação (BottomNavigationBar)

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'Telas/Inicio.dart';
import 'firebase_options.dart';
import 'Telas/Cartoes.dart';
import 'Telas/Outros.dart';
import 'Telas/Dasboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int currentIndex = 0;

  final List<Widget> screens = [
    HomeScreen(),
    CardConfigScreen(),
    DashboardScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[currentIndex],
      bottomNavigationBar: Container(
  margin: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Colors.black,
    borderRadius: BorderRadius.circular(25),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.4),
        blurRadius: 10,
        offset: Offset(0, 5),
      ),
    ],
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(25),
    child: BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) {
        setState(() {
          currentIndex = index;
        });
      },
      backgroundColor: Colors.black,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.blueAccent,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: false,
      selectedLabelStyle: TextStyle(
        fontWeight: FontWeight.bold,
      ),
      items: [
        BottomNavigationBarItem(
          icon: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: currentIndex == 0
                  ? Colors.blueAccent.withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.home),
          ),
          label: 'Início',
        ),
        BottomNavigationBarItem(
          icon: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: currentIndex == 1
                  ? Colors.blueAccent.withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.credit_card),
          ),
          label: 'Cartões',
        ),
        BottomNavigationBarItem(
          icon: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: currentIndex == 2
                  ? Colors.blueAccent.withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.bar_chart),
          ),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: currentIndex == 3
                  ? Colors.blueAccent.withOpacity(0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.settings),
          ),
          label: 'Config',
        ),
      ],
    ),
  ),
),
    );
  }
}

