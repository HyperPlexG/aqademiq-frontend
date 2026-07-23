import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Open a URL (web link or mailto) in the platform handler, surfacing a snackbar
/// if no handler is available. Shared by Settings (Privacy/Terms) and Stats links.
Future<void> openExternal(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  var ok = false;
  try {
    // `externalApplication` is right for mail clients and apps, but on web a
    // mailto with no registered handler makes launchUrl *throw* rather than
    // return false. Uncaught, that surfaced as the link doing nothing at all.
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object {
    ok = false;
  }
  if (!ok) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          uri.scheme == 'mailto'
              ? 'No mail app found. Write to ${uri.path} instead.'
              : 'Could not open the link.',
        ),
      ),
    );
  }
}
