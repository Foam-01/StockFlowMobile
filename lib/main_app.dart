import 'package:flutter/material.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.deepPurple,
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
          ],
        ),
        body: const Center(child: Text('Flutter App')),
      ),
    );
  }
}
