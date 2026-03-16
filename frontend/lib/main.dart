import 'package:flutter/material.dart';
import 'package:ridematch/constants/app_routes.dart';
import 'package:ridematch/views/auth/Screens/LoginScreen.dart';
import 'package:ridematch/views/auth/Screens/SignupScreen.dart';
import 'package:ridematch/views/auth/Screens/forgetpassword.dart';
import 'package:ridematch/views/Splash/SplashScreen.dart';
import 'package:ridematch/views/admin/admin_dashboard.dart';
import 'package:ridematch/views/dashboard/Screens/Dashboard.dart';
import 'package:ridematch/views/payment/paymentpage.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RideMatch',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      routes: {
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.signup: (context) => const SignUpScreen(),
        AppRoutes.forgotPassword: (context) => const ForgetPasswordScreen(),
        AppRoutes.home: (context) => const DashboardScreen(),
        AppRoutes.payments: (context) => const PaymentPage(),
        AppRoutes.adminDashboard: (context) => const AdminDashboardScreen(),
      },
      home: SplashScreen(),
    );
  }
}
