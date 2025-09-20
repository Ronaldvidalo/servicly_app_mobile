class AppUser {
  final String uid;
  final String? email;
  final bool isProfileComplete;
 

  AppUser({
    required this.uid,
    this.email,
    this.isProfileComplete = false,
    
  });
}