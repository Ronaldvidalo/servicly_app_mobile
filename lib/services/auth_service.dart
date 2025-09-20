import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:servicly_app/models/app_user.dart'; // Asegúrate de que esta ruta a tu modelo sea correcta

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Este Stream combina la autenticación y los datos de Firestore en un solo flujo
  Stream<AppUser?> get user {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      // Si no hay usuario en Firebase Auth (sesión cerrada), no hacemos nada.
      if (firebaseUser == null) {
        return null;
      }

      // Si hay un usuario, buscamos su documento en la colección 'usuarios'.
      final userDoc = await _firestore.collection('usuarios').doc(firebaseUser.uid).get();

      // Si el documento del usuario existe...
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        // ...creamos y devolvemos nuestro objeto AppUser con todos los datos.
        return AppUser(
          uid: firebaseUser.uid,
          email: firebaseUser.email,
          isProfileComplete: userData['profileComplete'] ?? false,
          // Aquí puedes añadir los otros campos que necesites, ej:
          // nombre: userData['nombre'],
        );
      } else {
        // Si el documento no existe (ej. un usuario recién registrado),
        // devolvemos un AppUser básico solo con la información de Auth.
        return AppUser(
          uid: firebaseUser.uid,
          email: firebaseUser.email,
        );
      }
    });
  }

  // En el futuro, puedes mover tus métodos de signOut, signIn, etc., aquí para mantener todo organizado.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}