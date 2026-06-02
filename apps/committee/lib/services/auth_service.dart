import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

// ─── Configuration ────────────────────────────────────────────────────────────
// Set these before deploying to production.
//
// ZeptoMail:
//   1. Create an account at https://zeptomail.zoho.com
//   2. Add and verify a sending domain
//   3. Generate an API token under Settings → API Tokens
//   4. Replace the values below
//
// Google Sign-In:
//   1. Go to https://console.cloud.google.com → APIs & Services → Credentials
//   2. Create an OAuth 2.0 Client ID (Web application)
//   3. Add your GitHub Pages URL to Authorized JavaScript origins
//      e.g. https://yourusername.github.io
//   4. Replace _kGoogleClientId below
//
const _kZeptoApiKey = 'PHtE6r0JEenoijYr8xZR7PbsF8KjY4Iv+u5iLQRAuI5GA/MKGk0Drt19w2S3qBYiXPlFFvXPnNk+t7icte7ULGnlZzseD2qyqK3sx/VYSPOZsbq6x00ct1gSdkzZVo/td95u0iHUuN7cNA==';
const _kZeptoSender = 'noreply@akzapps.in'; // verified sender in ZeptoMail
const _kGoogleClientId = '143794639055-68ud64nik3bg818fei6ug29qa16lm9b8.apps.googleusercontent.com';
// ─────────────────────────────────────────────────────────────────────────────

class AuthService {
  AuthService._();

  static final _google = GoogleSignIn(
    clientId: _kGoogleClientId,
    scopes: ['email', 'profile'],
  );

  // OTPs are stored as hashes under _auth_otps/{emailHash} in Firebase RTDB.
  static final _otpDb = FirebaseDatabase.instance.ref('_auth_otps');

  // ── Google Sign-In ─────────────────────────────────────────────────────────

  /// Opens the Google account picker and returns {email, name}.
  static Future<({String email, String name})> googleSignIn() async {
    if (_kGoogleClientId == 'YOUR_CLIENT_ID.apps.googleusercontent.com') {
      throw Exception('Google Sign-In is not configured yet. '
          'See auth_service.dart for setup instructions.');
    }
    await _google.signOut(); // always show account picker
    final account = await _google.signIn();
    if (account == null) throw Exception('Google sign-in was cancelled.');
    return (
      email: account.email.trim().toLowerCase(),
      name: (account.displayName ?? account.email.split('@').first).trim(),
    );
  }

  // ── Email OTP ──────────────────────────────────────────────────────────────

  /// Generates a 6-digit OTP, stores its hash in RTDB (expires in 10 min),
  /// and sends the code to [email] via ZeptoMail.
  static Future<void> sendOtp(String email, String appName) async {
    if (_kZeptoApiKey == 'YOUR_ZEPTO_MAIL_API_KEY') {
      throw Exception('ZeptoMail is not configured yet. '
          'See auth_service.dart for setup instructions.');
    }
    final otp = _generateOtp();
    final key = _emailKey(email);
    final exp = DateTime.now().toUtc()
        .add(const Duration(minutes: 10))
        .millisecondsSinceEpoch;

    // Store only the hash — never store the plaintext OTP
    await _otpDb.child(key).set({'h': _hashOtp(otp, email), 'exp': exp});

    await _callZeptoMail(
      to: email,
      subject: 'Your $appName login code',
      html: _buildEmailHtml(otp, appName),
    );
  }

  /// Returns true if [otp] matches the stored hash and has not expired.
  /// Deletes the record on success (one-time use).
  static Future<bool> verifyOtp(String email, String otp) async {
    final key = _emailKey(email);
    final snap = await _otpDb.child(key).get();
    if (!snap.exists || snap.value == null) return false;

    final data = Map<String, dynamic>.from(snap.value as Map);
    final exp = data['exp'] as int?;
    final hash = data['h'] as String?;
    if (exp == null || hash == null) return false;

    if (DateTime.now().toUtc().millisecondsSinceEpoch > exp) {
      await _otpDb.child(key).remove();
      return false;
    }

    if (_hashOtp(otp.trim(), email) != hash) return false;

    await _otpDb.child(key).remove(); // invalidate after use
    return true;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static String _generateOtp() {
    final r = Random.secure();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }

  static String _emailKey(String email) {
    final bytes = utf8.encode(email.trim().toLowerCase());
    return sha256.convert(bytes).toString().substring(0, 24);
  }

  static String _hashOtp(String otp, String email) {
    final payload = '${otp.trim()}|${email.trim().toLowerCase()}';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  static Future<void> _callZeptoMail({
    required String to,
    required String subject,
    required String html,
  }) async {
    final resp = await http.post(
      Uri.parse('https://api.zeptomail.in/v1.1/email'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Zoho-enczapikey $_kZeptoApiKey',
      },
      body: jsonEncode({
        'from': {'address': _kZeptoSender},
        'to': [
          {'email_address': {'address': to}}
        ],
        'subject': subject,
        'htmlbody': html,
      }),
    );
    if (resp.statusCode >= 300) {
      throw Exception(
          'Could not send verification email (HTTP ${resp.statusCode}). '
          'Check your ZeptoMail API key and sender domain.');
    }
  }

  static String _buildEmailHtml(String otp, String appName) => '''
<!DOCTYPE html>
<html>
<body style="font-family:-apple-system,BlinkMacSystemFont,Arial,sans-serif;background:#f5f5f7;margin:0;padding:24px;">
<div style="max-width:480px;margin:0 auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,.08);">
  <div style="background:#0891B2;padding:24px;text-align:center;">
    <h1 style="color:#fff;margin:0;font-size:20px;font-weight:700;">$appName</h1>
  </div>
  <div style="padding:36px 28px;text-align:center;">
    <p style="color:#333;font-size:16px;font-weight:600;margin:0 0 6px;">Your login code</p>
    <p style="color:#888;font-size:13px;margin:0 0 28px;">Use this to sign in to $appName</p>
    <div style="font-size:46px;font-weight:800;letter-spacing:14px;color:#0891B2;background:#f0f9ff;padding:22px 16px;border-radius:14px;margin-bottom:28px;display:inline-block;">$otp</div>
    <p style="color:#999;font-size:12px;margin:0;line-height:1.7;">
      Valid for <strong>10 minutes</strong><br>
      Never share this code with anyone
    </p>
  </div>
</div>
</body>
</html>''';
}
