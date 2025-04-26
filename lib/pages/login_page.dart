import 'package:flutter/material.dart';
import 'package:phone_auth_firebase_tutorial/controllers/auth_service.dart';
import 'package:phone_auth_firebase_tutorial/pages/home_page.dart';
import 'package:telephony/telephony.dart';
import 'dart:io' show Platform;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final Telephony telephony = Telephony.instance;
  bool isLoading = false;
  TextEditingController _phoneController = TextEditingController();
  TextEditingController _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _formKey1 = GlobalKey<FormState>();

  void listenToIncomingSMS(BuildContext context) {
    if (Platform.isAndroid) {
      print("Listening to sms on Android.");
      telephony.listenIncomingSms(
          onNewMessage: (SmsMessage message) {
            print("sms received : ${message.body}");
            if (message.body!.contains("phone-auth-15bdb")) {
              String otpCode = message.body!.substring(0, 6);
              setState(() {
                _otpController.text = otpCode;
                Future.delayed(Duration(seconds: 1), () {
                  handleSubmit(context);
                });
              });
            }
          },
          listenInBackground: false);
    } else {
      print("SMS listening not supported on this platform");
    }
  }

  void handleSubmit(BuildContext context) async {
    if (_formKey1.currentState!.validate()) {
      setState(() {
        isLoading = true;
      });

      try {
        String result =
            await AuthService.loginWithOtp(otp: _otpController.text);
        if (result == "Success") {
          Navigator.pop(context);
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (context) => HomePage()));
        } else {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result, style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
          ));
        }
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> handleSendOTP() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        isLoading = true;
      });

      try {
        await AuthService.sentOtp(
            phone: _phoneController.text,
            errorStep: (String errorMessage) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    Text(errorMessage, style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ));
            },
            nextStep: () {
              listenToIncomingSMS(context);
              showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                        title: Text("OTP Verification"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                "Enter 6 digit OTP sent to +91${_phoneController.text}"),
                            SizedBox(height: 12),
                            Form(
                              key: _formKey1,
                              child: TextFormField(
                                keyboardType: TextInputType.number,
                                controller: _otpController,
                                decoration: InputDecoration(
                                    labelText: "Enter OTP",
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(32))),
                                validator: (value) {
                                  if (value == null || value.length != 6)
                                    return "Invalid OTP";
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text("Cancel")),
                          TextButton(
                              onPressed: () => handleSubmit(context),
                              child: Text("Submit"))
                        ],
                      ));
            });
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Container(
              height: MediaQuery.of(context).size.height,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      child: Image.asset(
                    "images/login.png",
                    fit: BoxFit.cover,
                  )),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Welcome Back 👋",
                          style: TextStyle(
                              fontSize: 32, fontWeight: FontWeight.w700),
                        ),
                        Text("Enter your phone number to continue."),
                        SizedBox(height: 20),
                        Form(
                          key: _formKey,
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                                prefixText: "+91 ",
                                labelText: "Enter your phone number",
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(32))),
                            validator: (value) {
                              if (value == null || value.length != 10)
                                return "Invalid phone number";
                              return null;
                            },
                          ),
                        ),
                        SizedBox(height: 20),
                        SizedBox(
                          height: 50,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : handleSendOTP,
                            child: Text("Send OTP"),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.yellow,
                                foregroundColor: Colors.black),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
