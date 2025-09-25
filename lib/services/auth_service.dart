// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:servicly_app/models/app_user.dart';
import 'dart:developer' as developer;

String? referrerId;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<AppUser?> get user {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) {
        return null;
      }

      DocumentSnapshot userDoc = await _firestore.collection('usuarios').doc(firebaseUser.uid).get();

      if (!userDoc.exists) {
        // Usamos developer.log en lugar de print
        developer.log("Documento no encontrado en el primer intento. Reintentando en 500ms...", name: 'AuthService');
        await Future.delayed(const Duration(milliseconds: 500));
        userDoc = await _firestore.collection('usuarios').doc(firebaseUser.uid).get();
      }
      
      if (userDoc.exists) {
        // ✅ CORRECCIÓN CLAVE: Le decimos a Dart que 'data()' es un Map.
        final userData = userDoc.data()! as Map<String, dynamic>; 
        
        // Ahora userData es un Map y los siguientes métodos son válidos.
        final bool profileFlag = userData['profileComplete'] ?? false;
        final bool hasRequiredFields = userData.containsKey('rol_user') && userData.containsKey('pais');
        final bool isTrulyComplete = profileFlag && hasRequiredFields;

        return AppUser(
          uid: firebaseUser.uid,
          email: firebaseUser.email,
          isProfileComplete: isTrulyComplete,
        );
      } else {
        // Usamos developer.log aquí también
        developer.log("Estado inconsistente persistente detectado. Forzando cierre de sesión.", name: 'AuthService');
        await _auth.signOut();
        return null; 
      }
    });
  }


  // --- MÉTODOS DE AUTENTICACIÓN (Ya no piden permiso de notificación) ---

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        await _checkAndCreateUserProfile(userCredential.user!);
      }
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }
  
  Future<UserCredential?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = userCredential.user;
      if (user != null) {
        await user.updateDisplayName(displayName);
        await _firestore.collection('usuarios').doc(user.uid).set({
          'uid': user.uid,
          'display_name': displayName,
          'email': email,
          'photo_url': null,
          'created_time': FieldValue.serverTimestamp(),
          'rating': 0.0,
          'ratingCount': 0,
          'plan': 'fundador',
          'esVerificado': false,
          'profileComplete': false,
          'referredBy': referrerId, 
          'referralCount': 0,
        });
        
        referrerId = null;
      }
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }
  
  Future<void> _checkAndCreateUserProfile(User user) async {
    final userDocRef = _firestore.collection('usuarios').doc(user.uid);
    final docSnapshot = await userDocRef.get();
    if (!docSnapshot.exists) {
      await userDocRef.set({
        'uid': user.uid,
        'display_name': user.displayName ?? 'Usuario Anónimo',
        'email': user.email,
        'photo_url': user.photoURL,
        'created_time': FieldValue.serverTimestamp(),
        'rating': 0.0,
        'ratingCount': 0,
        'plan': 'fundador',
        'esVerificado': false,
        'profileComplete': false,
        'referredBy': referrerId,
        'referralCount': 0,
      });
      referrerId = null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}