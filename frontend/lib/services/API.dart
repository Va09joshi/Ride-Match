import 'package:ridematch/utils/app_constant.dart';

class AppApi {
  static const String baseUrl = 'https://ride-match-backend.onrender.com';
  // static const String baseUrl = 'http://192.168.29.206:5000';
  // static const String baseUrl = 'http://10.213.29.104:5000';

  static Uri uri(String path, {Map<String, dynamic>? queryParameters}) {
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }
}

class ApiPaths {
  static const String authSignup = AppEndpoints.authSignup;
  static const String authLogin = AppEndpoints.authLogin;
  static const String authForgotPassword = AppEndpoints.authForgotPassword;
  static const String authVerifyOtp = AppEndpoints.authVerifyOtp;
  static const String authResetPassword = AppEndpoints.authResetPassword;
}

const String baseurl = AppApi.baseUrl;
