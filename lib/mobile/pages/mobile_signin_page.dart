import 'package:flutter/material.dart';

class MobileSignIn extends StatefulWidget {
  const MobileSignIn({super.key});

  @override
  State<MobileSignIn> createState() => _MobileSignInState();
}

class _MobileSignInState extends State<MobileSignIn> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Sign-In'),
      ),
    );
  }
}
