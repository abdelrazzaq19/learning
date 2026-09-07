import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// Sends the certificate PDF by email.
///
/// Credentials come from the build environment, never from source:
///
///   flutter run --dart-define=SMTP_USERNAME=you@gmail.com ///               --dart-define=SMTP_PASSWORD=your-app-password
///
/// When they are unset, [isConfigured] is false and sending is skipped — the
/// caller still has the PDF saved locally.
class CertificationEmailService {
  static const String username =
      String.fromEnvironment('SMTP_USERNAME', defaultValue: '');
  static const String password =
      String.fromEnvironment('SMTP_PASSWORD', defaultValue: '');

  static bool get isConfigured => username.isNotEmpty && password.isNotEmpty;

  /// Method to send certification email with attached PDF
  /// Returns true when the email was actually sent.
  Future<bool> sendCertification({
    required String receiverEmail,
    required File pdfFile,
    required String candidateName,
    required String examName,
    required String score,
    required String examDate,
  }) async {
    if (!isConfigured) {
      debugPrint(
        'SMTP is not configured; skipping the certificate email. '
        'Pass --dart-define=SMTP_USERNAME and SMTP_PASSWORD to enable it.',
      );
      return false;
    }

    // Configure the SMTP server
    final smtpServer = SmtpServer(
      'smtp.gmail.com',
      port: 465,
      ssl: true,
      username: username,
      password: password,
    );

    // Create the email message
    final message = Message()
      ..from = const Address(username, 'PSTU E-Learning')
      ..recipients.add(receiverEmail)
      ..subject = 'Certification of Achievement - $examName'
      ..html = '''
    <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
      <div style="margin: 20px auto; width: 80%; padding: 20px; border: 1px solid #ddd; border-radius: 8px;">
        <h2 style="color: #00466a;">PSTU Certification Board</h2>
        <p>Dear $candidateName,</p>
        <p>Congratulations on successfully completing the <strong>$examName</strong> exam! Below are your exam details:</p>
        
        <div style="margin: 15px 0; padding: 15px; background-color: #f9f9f9; border-radius: 6px;">
          <p><strong>Exam Name:</strong> $examName</p>
          <p><strong>Score:</strong> $score</p>
          <p><strong>Exam Date:</strong> $examDate</p>
        </div>
        
        <p>Please find your official certification attached to this email. If you have any questions or require further assistance, feel free to contact us.</p>
        
        <p style="font-size: 0.9em; color: #555;">Thank you for choosing PSTU Certification Board!</p>
        
        <p style="font-size: 0.9em;">Regards,<br>PSTU E-Learning Team</p>
        <hr style="border-top: 1px solid #ddd;">
        <p style="font-size: 0.8em; color: #999;">PSTU Certification Board | Bangladesh</p>
      </div>
    </div>
    ''';

    // Attach the PDF using FileAttachment
    try {
      message.attachments.add(FileAttachment(pdfFile)
        ..fileName = '${candidateName}_Certification.pdf');
    } catch (e) {
      debugPrint('Failed to attach the PDF file: $e');
      return false;
    }

    // Send the email
    try {
      final sendReport = await send(message, smtpServer);
      debugPrint('Certification email sent: $sendReport');
      return true;
    } on MailerException catch (e) {
      debugPrint('Certification email not sent: $e');
      for (final problem in e.problems) {
        debugPrint('Problem: ${problem.code}: ${problem.msg}');
      }
      return false;
    } catch (e) {
      debugPrint('Certification email not sent: $e');
      return false;
    }
  }
}
