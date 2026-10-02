class AppUser {
  final int id;
  final String name, email, userType;
  final String? phone;
  final bool verified, banned;
  AppUser.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        name = j['name'],
        email = j['email'],
        userType = j['user_type'] ?? 'customer',
        phone = j['phone'],
        verified = j['verified'] ?? false,
        banned = j['banned'] ?? false;

  bool get isAdmin => userType == 'admin';
  bool get isSeller => userType == 'seller';
}
