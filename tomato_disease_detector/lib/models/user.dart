class User {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String fullName;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.fullName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final firstName = json['first_name'] ?? '';
    final lastName = json['last_name'] ?? '';
    final email = json['email'] ?? '';
    return User(
      id: json['id'] ?? 0,
      username: json['username'] ?? email,
      email: email,
      firstName: firstName,
      lastName: lastName,
      fullName: json['full_name'] ?? '$firstName $lastName'.trim(),
    );
  }

  String get displayName {
    if (fullName.trim().isNotEmpty) return fullName;
    if (firstName.trim().isNotEmpty) return firstName;
    if (email.contains('@')) return email.split('@').first;
    return 'Farmer';
  }
}
