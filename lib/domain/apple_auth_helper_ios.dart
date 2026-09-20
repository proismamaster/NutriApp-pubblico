// ignore_for_file: undefined_class, undefined_identifier, uri_does_not_exist
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

// ignore: non_type_as_type_argument
Future<List<dynamic>> getAppleScopes() async => [
  'email',
  'fullName',
];

Future<dynamic> performAppleSignIn(List<dynamic> scopes) async {
  return await SignInWithApple.getAppleIDCredential(
    scopes: [
      AppleIDAuthorizationScope.email,
      AppleIDAuthorizationScope.fullName,
    ],
  );
}
