import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Generate 6-character room code
  String generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  // Anonymous authentication
  Future<String> signInAnonymously() async {
    final userCredential = await _auth.signInAnonymously();
    return userCredential.user!.uid;
  }
}
