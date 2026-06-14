import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

const _kZeptoProxyUrl = 'https://zepto-proxy.akshay-zoho-06.workers.dev/';
const _kZeptoProxySecret = 'akzapps-otp-cf-2026';
const _kZeptoSender = 'noreply@akzapps.in';
const _kGoogleClientId = '143794639055-68ud64nik3bg818fei6ug29qa16lm9b8.apps.googleusercontent.com';

class AuthService {
  AuthService._();

  static final _google = GoogleSignIn(
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

  // ── Kuri invite email ──────────────────────────────────────────────────────

  static const _kAppUrl = 'https://akzzoho.github.io/my-apps/kuri/?invite=1';

  static Future<void> sendKuriInviteEmail({
    required String to,
    required String kuriName,
    required String inviterName,
    required double monthlyAmount,
  }) async {
    await _callZeptoMail(
      to: to,
      subject: 'You\'ve been added to a Kuri plan',
      html: _buildInviteEmailHtml(kuriName, inviterName, monthlyAmount),
    );
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
      Uri.parse(_kZeptoProxyUrl),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Secret': _kZeptoProxySecret,
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
          'Could not send verification email (HTTP ${resp.statusCode}).');
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

  static String _buildInviteEmailHtml(
      String kuriName, String inviterName, double monthlyAmount) =>
      '''
<!DOCTYPE html>
<html>
<body style="font-family:-apple-system,BlinkMacSystemFont,Arial,sans-serif;background:#f5f5f7;margin:0;padding:24px;">
<div style="max-width:480px;margin:0 auto;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,.08);">
  <div style="background:#0E6E6E;padding:24px;text-align:center;">
    <div style="display:inline-block;background:rgba(255,255,255,0.15);border-radius:16px;padding:12px 20px;">
      <span style="color:#fff;font-size:28px;font-weight:800;letter-spacing:-1px;">₹ Kuri</span>
    </div>
  </div>
  <div style="padding:36px 28px;">
    <p style="color:#333;font-size:18px;font-weight:700;margin:0 0 8px;">You've been added to a Kuri!</p>
    <p style="color:#666;font-size:14px;margin:0 0 24px;line-height:1.6;">
      <strong>$inviterName</strong> has added you to the savings plan:
    </p>
    <div style="background:#f0f9f9;border:1px solid #b2dfdb;border-radius:12px;padding:20px;margin-bottom:28px;text-align:center;">
      <p style="color:#0E6E6E;font-size:20px;font-weight:800;margin:0 0 6px;">$kuriName</p>
      <p style="color:#555;font-size:14px;margin:0;">₹${monthlyAmount.toInt()} / month</p>
    </div>
    <div style="text-align:center;margin-bottom:28px;">
      <a href="$_kAppUrl" style="display:inline-block;background:#0E6E6E;color:#fff;text-decoration:none;font-size:15px;font-weight:700;padding:14px 36px;border-radius:12px;">
        Open Kuri App →
      </a>
    </div>
    <p style="color:#999;font-size:12px;margin:0;text-align:center;line-height:1.7;">
      Log in with your email to view your Kuri plan and payment schedule.
    </p>
  </div>
</div>
</body>
</html>''';
}
