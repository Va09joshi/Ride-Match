import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ridematch/services/API.dart';

class AuthService {
  static final Uri _signupUri = AppApi.uri(ApiPaths.authSignup);
  static final Uri _loginUri = AppApi.uri(ApiPaths.authLogin);
  static final Uri _forgotPasswordUri = AppApi.uri(ApiPaths.authForgotPassword);
  static final Uri _verifyOtpUri = AppApi.uri(ApiPaths.authVerifyOtp);
  static final Uri _resetPasswordUri = AppApi.uri(ApiPaths.authResetPassword);

  static Future<AuthResponse> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) {
    return _post(
      _signupUri,
      body: {
        'name': name,
        'email': email,
        'phone': phone,
        'password': password,
      },
    );
  }

  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) {
    return _post(_loginUri, body: {'email': email, 'password': password});
  }

  static Future<AuthResponse> forgotPassword({required String email}) {
    return _post(_forgotPasswordUri, body: {'email': email});
  }

  static Future<AuthResponse> verifyOtp({
    required String email,
    required String otp,
  }) {
    return _post(_verifyOtpUri, body: {'email': email, 'otp': otp});
  }

  static Future<AuthResponse> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) {
    return _post(
      _resetPasswordUri,
      body: {
        'email': email,
        'resetToken': resetToken,
        'newPassword': newPassword,
      },
    );
  }

  static Future<AuthResponse> _post(
    Uri uri, {
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      Map<String, dynamic> payload = <String, dynamic>{};
      if (response.body.isNotEmpty) {
        try {
          payload = jsonDecode(response.body) as Map<String, dynamic>;
        } catch (_) {
          payload = {'success': false, 'message': response.body};
        }
      }

      payload['success'] ??=
          response.statusCode >= 200 && response.statusCode < 300;
      payload['message'] ??=
          response.statusCode >= 200 && response.statusCode < 300
          ? 'Request successful'
          : 'Request failed';

      return AuthResponse(statusCode: response.statusCode, data: payload);
    } on TimeoutException {
      return AuthResponse(
        statusCode: 408,
        data: const {
          'success': false,
          'message': 'Request timed out. Please try again.',
        },
      );
    } catch (_) {
      return AuthResponse(
        statusCode: 500,
        data: const {'success': false, 'message': 'Error connecting to server'},
      );
    }
  }
}

class AuthResponse {
  const AuthResponse({required this.statusCode, required this.data});

  final int statusCode;
  final Map<String, dynamic> data;

  bool get isSuccess =>
      statusCode >= 200 && statusCode < 300 && data['success'] == true;

  String get message => (data['message'] ?? 'Something went wrong').toString();
}
