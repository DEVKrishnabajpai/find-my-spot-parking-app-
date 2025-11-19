import 'package:flutter/material.dart';
import 'package:parking_app/screens/auth.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:parking_app/screens/selectmodesscreen.dart';
import 'firebase_options.dart';

import 'package:firebase_auth/firebase_auth.dart';
 


void main()async {
 WidgetsFlutterBinding.ensureInitialized();
await Firebase.initializeApp(
 options: DefaultFirebaseOptions.currentPlatform,
 );
 runApp(const MyApp());
}

class MyApp extends StatelessWidget {
 
 const MyApp({super.key});

 @override
 Widget build(BuildContext context) {
 return MaterialApp(
 title: 'Flutter Demo',
 theme: ThemeData(
 colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
 ),
 home: StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (ctx, snapshot) {
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: SelectModeScreen(),
              ),
            );
          }

          if (snapshot.hasData) {
            return SelectModeScreen(); 
          }
          return const Auth(); 
        },
      ),
 );
 }
}
//flutter run -d RZCY21JNV8L
// Flutter run key commands.
// r Hot reload.
// R Hot restart.
// h List all available interactive commands.
// d Detach (terminate "flutter run" but leave application running).
// c Clear the screen
// q Quit (terminate the application on the device).