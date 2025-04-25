import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  static String verifyId = "";
  static DateTime? _lastOtpRequest;
  static const _otpCooldown = Duration(minutes: 2);

  static Future<bool> _canRequestOtp() async {
    if (_lastOtpRequest == null) return true;
    return DateTime.now().difference(_lastOtpRequest!) >= _otpCooldown;
  }

  static String _getErrorMessage(String code) {
    switch (code) {
      case 'too-many-requests':
        return 'Too many attempts. Please try again after some time.';
      case 'invalid-phone-number':
        return 'Invalid phone number format.';
      case 'internal-error':
        return 'Service temporarily unavailable. Please try again.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  static Future sentOtp({
    required String phone,
    required Function errorStep,
    required Function nextStep,
  }) async {
    try {
      if (!await _canRequestOtp()) {
        errorStep();
        return;
      }

      _lastOtpRequest = DateTime.now();

      if (kDebugMode) {
        print("Sending OTP to +91$phone");
      }

      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: "+91$phone",
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final result = await _firebaseAuth.signInWithCredential(credential);
            if (result.user != null) {
              nextStep();
            } else {
              errorStep();
            }
          } catch (e) {
            print("Auto verification error: $e");
            errorStep();
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          print("Verification failed: ${e.code} - ${e.message}");
          String errorMessage = _getErrorMessage(e.code);
          errorStep();
        },
        codeSent: (String verificationId, int? resendToken) {
          verifyId = verificationId;
          nextStep();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          verifyId = verificationId;
        },
      );
    } catch (e) {
      print("Error in sentOtp: $e");
      errorStep();
    }
  }

  static Future<String> loginWithOtp({required String otp}) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verifyId,
        smsCode: otp,
      );

      final result = await _firebaseAuth.signInWithCredential(credential);
      return result.user != null ? "Success" : "Failed to verify OTP";
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print("Firebase Auth Exception: ${e.message}");
      }
      return e.message ?? "An error occurred";
    } catch (e) {
      if (kDebugMode) {
        print("Error in loginWithOtp: $e");
      }
      return "An unexpected error occurred";
    }
  }

  // to logout the user
  static Future logout() async {
    await _firebaseAuth.signOut();
  }

  // check whether the user is logged in or not
  static Future<bool> isLoggedIn() async {
    var user = _firebaseAuth.currentUser;
    return user != null;
  }
}
