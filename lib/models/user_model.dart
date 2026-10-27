class UserModel {
  final int id;
  final String uid;
  final String username;
  final String email;
  final String? avatar;
  final String provider;
  final String? createdAt;
  final String? updatedAt;
  final bool isGuest;

  UserModel({
    required this.id,
    required this.uid,
    String username = '',
    String? displayName,
    required this.email,
    String? avatar,
    String? photoURL,
    this.provider = 'password',
    this.createdAt,
    this.updatedAt,
    this.isGuest = false,
  }) : username = (displayName != null && displayName.isNotEmpty)
           ? displayName
           : (username.isNotEmpty ? username : 'Pengguna MyMusic'),
       avatar = photoURL ?? avatar;

  String get displayName => username.isNotEmpty ? username : 'Pengguna MyMusic';
  String? get photoURL => avatar;

  /// Creates a dedicated Guest user profile.
  factory UserModel.guest() {
    final now = DateTime.now().toIso8601String();
    return UserModel(
      id: 0,
      uid: 'guest_user',
      username: 'Tamu',
      email: '',
      avatar: null,
      provider: 'guest',
      createdAt: now,
      updatedAt: now,
      isGuest: true,
    );
  }

  /// Creates a profile mapped directly from Firebase user data (Google, Email/Password, etc.).
  factory UserModel.fromFirebaseUser({
    required String uid,
    String? displayName,
    String? email,
    String? photoUrl,
    String provider = 'google',
  }) {
    final now = DateTime.now().toIso8601String();
    final name = (displayName != null && displayName.trim().isNotEmpty)
        ? displayName.trim()
        : (email != null && email.contains('@')
              ? email.split('@').first
              : 'MyMusic User');
    return UserModel(
      id: uid.hashCode.abs(),
      uid: uid,
      username: name,
      email: email ?? '',
      avatar: photoUrl,
      provider: provider,
      createdAt: now,
      updatedAt: now,
      isGuest: false,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final uid = json['uid']?.toString() ?? json['id']?.toString() ?? '';
    final numericId = rawId is int
        ? rawId
        : (int.tryParse(rawId?.toString() ?? '') ?? uid.hashCode.abs());

    return UserModel(
      id: numericId,
      uid: uid,
      username:
          json['username'] ??
          json['displayName'] ??
          json['display_name'] ??
          json['name'] ??
          '',
      displayName:
          json['displayName'] ??
          json['display_name'] ??
          json['username'] ??
          json['name'],
      email: json['email'] ?? '',
      avatar: json['avatar'] ?? json['photoURL'] ?? json['photo_url'],
      photoURL: json['photoURL'] ?? json['photo_url'] ?? json['avatar'],
      provider: json['provider'] ?? 'password',
      createdAt: json['created_at'] ?? json['createdAt'],
      updatedAt: json['updated_at'] ?? json['updatedAt'],
      isGuest: json['isGuest'] == true || json['provider'] == 'guest',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uid': uid,
      'username': username,
      'displayName': displayName,
      'display_name': displayName,
      'email': email,
      'avatar': avatar,
      'photoURL': photoURL,
      'photo_url': photoURL,
      'provider': provider,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'isGuest': isGuest,
    };
  }

  UserModel copyWith({
    int? id,
    String? uid,
    String? username,
    String? email,
    String? avatar,
    String? provider,
    String? createdAt,
    String? updatedAt,
    bool? isGuest,
  }) {
    return UserModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      username: username ?? this.username,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      provider: provider ?? this.provider,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isGuest: isGuest ?? this.isGuest,
    );
  }
}
