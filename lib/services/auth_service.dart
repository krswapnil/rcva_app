import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Keep a single instance to manage session properly
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// ✅ Forces account chooser every time
  Future<UserCredential> signInWithGoogle() async {
    // This forces Google to forget the last-used account
    await _googleSignIn.signOut();

    final GoogleSignInAccount? gUser = await _googleSignIn.signIn();
    if (gUser == null) {
      throw Exception('Sign-in cancelled');
    }

    final gAuth = await gUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }

  /// ✅ Full logout: Firebase + Google signOut + disconnect
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();

    // Disconnect clears cached auth so chooser shows next time
    try {
      await _googleSignIn.disconnect();
    } catch (_) {}
  }
}
