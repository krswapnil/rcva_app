import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Keep a single instance to manage session properly
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// ✅ Normal sign-in (keeps user logged in across app restarts)
  Future<UserCredential> signInWithGoogle() async {
    // Do NOT signOut here. This is what was causing “logout on close”.
    // await _googleSignIn.signOut(); ❌ remove

    // Try to reuse existing Google session first (faster, no chooser)
    GoogleSignInAccount? gUser = await _googleSignIn.signInSilently();

    // If no cached session, show the sign-in UI
    gUser ??= await _googleSignIn.signIn();

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

  /// ✅ Optional: if you want an explicit "Switch Account" flow
  Future<UserCredential> signInWithGoogleForceChooser() async {
    // This forces account chooser
    await _googleSignIn.signOut();
    final gUser = await _googleSignIn.signIn();
    if (gUser == null) throw Exception('Sign-in cancelled');

    final gAuth = await gUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }

  /// ✅ Full logout (user-initiated)
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();

    // Optional: disconnect clears cached auth (use only if you WANT this behavior)
    // try { await _googleSignIn.disconnect(); } catch (_) {}
  }
}
