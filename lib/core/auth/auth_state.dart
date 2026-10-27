/// Centralized authentication state enum for MyMusic.
enum AuthStatus {
  /// Session state is currently being loaded or verified on startup.
  loading,

  /// User is fully authenticated (Firebase Auth: Google, Email/Password, etc.).
  authenticated,

  /// User opted into Guest Mode; app is usable with guest status.
  guest,

  /// User is not logged in; auth screens are accessible.
  unauthenticated,
}
