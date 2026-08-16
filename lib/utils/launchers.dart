import 'package:url_launcher/url_launcher.dart';

Future<void> launchPhoneCall(String phone) async {
  final uri = Uri(scheme: 'tel', path: phone);
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

Future<void> launchSmsMessage(String phone) async {
  final uri = Uri(scheme: 'sms', path: phone);
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

Future<void> launchEmailCompose(String email) async {
  final uri = Uri(scheme: 'mailto', path: email);
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}
