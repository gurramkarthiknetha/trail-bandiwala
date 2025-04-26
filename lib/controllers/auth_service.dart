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
        errorStep("Please wait before requesting another OTP");
        return;
      }

      _lastOtpRequest = DateTime.now();

      // Disable reCAPTCHA verification for all platforms
      _firebaseAuth.setSettings(appVerificationDisabledForTesting: true);

      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: "+91$phone",
        timeout: const Duration(seconds: 120), // Increase timeout to 2 minutes
        forceResendingToken: null,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            // This callback is triggered on Android when auto-verification happens
            await _firebaseAuth.signInWithCredential(credential);
            if (kDebugMode) {
              print("Auto verification completed");
            }
            nextStep();
          } catch (e) {
            if (kDebugMode) {
              print("Error in auto verification: $e");
            }
            errorStep("Auto verification failed. Please enter OTP manually.");
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (kDebugMode) {
            print("Verification failed: ${e.code} - ${e.message}");
          }
          String errorMessage = _getErrorMessage(e.code);
          errorStep(errorMessage);
        },
        codeSent: (String verificationId, int? resendToken) {
          if (kDebugMode) {
            print("OTP sent successfully. Verification ID: $verificationId");
          }
          verifyId = verificationId;
          nextStep();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (kDebugMode) {
            print("Auto retrieval timeout. Verification ID: $verificationId");
          }
          verifyId = verificationId;
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print("Error in sentOtp: $e");
      }
      errorStep("An unexpected error occurred");
    }
  }

  static Future<String> loginWithOtp({required String otp}) async {
    try {
      // Make sure verification ID is not empty
      if (verifyId.isEmpty) {
        return "Verification ID is missing. Please request OTP again.";
      }

      // Create credential with verification ID and OTP
      final credential = PhoneAuthProvider.credential(
        verificationId: verifyId,
        smsCode: otp,
      );

      // Sign in with the credential
      final result = await _firebaseAuth.signInWithCredential(credential);
      return result.user != null ? "Success" : "Failed to verify OTP";
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print("Firebase Auth Exception: ${e.code} - ${e.message}");
      }

      // Handle specific error codes
      switch (e.code) {
        case 'invalid-verification-code':
          return "The OTP you entered is invalid. Please check and try again.";
        case 'invalid-verification-id':
          return "Session expired. Please request a new OTP.";
        case 'session-expired':
          return "OTP session expired. Please request a new OTP.";
        default:
          return e.message ?? "An error occurred";
      }
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
