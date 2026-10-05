/// Akun yang sedang masuk (dari Google, disimpan server).
class AppUser {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;

  const AppUser({required this.id, required this.name, required this.email, this.avatarUrl});

  /// Huruf pertama nama untuk avatar tanpa foto.
  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email, 'avatar_url': avatarUrl};

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'].toString(),
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    avatarUrl: json['avatar_url'] as String?,
  );
}
