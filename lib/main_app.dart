import 'package:flutter/material.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color.fromARGB(255, 4, 89, 135),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('MyApp'),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                print('Notifcation icon pressed');
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                print('Settings icon pressed');
              },
            ),
            PopupMenuButton<String>(
              onSelected: (String result) {
                print('selected $result');
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'Settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings),
                      SizedBox(width: 12),
                      Text('Settings'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'Profile',
                  child: Row(
                    children: [
                      Icon(Icons.account_circle),
                      SizedBox(width: 12),
                      Text('Profile'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'Logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: 12),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: const Center(
          child: Text(
            'Flutter App',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 194, 22, 22),
            ),
          ),
        ),
      ),
    );
  }
}
