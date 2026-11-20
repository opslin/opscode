import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  ApiConstants._();

  static String get baseUrl => dotenv.env['BASE_URL'] ?? '';

  static const sendOtp = '/auth/send-otp';
  static const verifyOtp = '/auth/verify-otp';
  static const refreshToken = '/auth/refresh-token';
  static const logout = '/auth/logout';
}
