class LoginCredentials {
  final String email;
  final String password;

  const LoginCredentials({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };

  factory LoginCredentials.fromJson(Map<String, dynamic> json) {
    return LoginCredentials(
      email: json['email']?.toString() ?? '',
      password: json['password']?.toString() ?? '',
    );
  }
}
