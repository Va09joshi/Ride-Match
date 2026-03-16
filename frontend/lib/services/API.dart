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
  static const String authSignup = '/api/auth/signup';
  static const String authLogin = '/api/auth/login';
  static const String authForgotPassword = '/api/auth/forgot-password';
  static const String authVerifyOtp = '/api/auth/verify-otp';
  static const String authResetPassword = '/api/auth/reset-password';
}

const String baseurl = AppApi.baseUrl;
