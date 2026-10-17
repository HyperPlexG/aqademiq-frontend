import 'package:dio/dio.dart';

import '../models/apple_relink_status.dart';
import 'api_helpers.dart';
import 'mock_latency.dart';

/// Keeps Sign in with Apple opening the right account after the app moved
/// Apple developer teams (October 2026).
///
/// Apple gives each user a different id per team, so after the move a returning
/// Apple user no longer matches their own account — and for Hide My Email users
/// nothing else matches them either. A device that is still signed in can prove
/// whose account it is: it sends a fresh Apple identity token, and the server
/// moves this account's Apple sign-in to the id Apple issues now.
abstract interface class AppleRelinkSource {
  /// Whether this account still signs in with an Apple id from before the move.
  Future<bool> needed();

  /// [nonce] is the raw value whose SHA-256 was handed to Apple for [identityToken].
  Future<AppleRelinkStatus> relink({
    required String identityToken,
    required String nonce,
  });
}

class MockAppleRelinkSource implements AppleRelinkSource {
  /// Mock accounts have no Apple history from before the move.
  @override
  Future<bool> needed() => mockDelay(false);

  @override
  Future<AppleRelinkStatus> relink({
    required String identityToken,
    required String nonce,
  }) =>
      mockDelay(AppleRelinkStatus.noAppleIdentity);
}

/// Live impl — `/v1/me/apple-relink`.
class ApiAppleRelinkSource implements AppleRelinkSource {
  ApiAppleRelinkSource(this._dio);
  final Dio _dio;

  @override
  Future<bool> needed() async =>
      (await _dio.getMap('/me/apple-relink'))['needed'] == true;

  @override
  Future<AppleRelinkStatus> relink({
    required String identityToken,
    required String nonce,
  }) async {
    final body = await _dio.postMap('/me/apple-relink', {
      'identity_token': identityToken,
      'nonce': nonce,
    });
    return AppleRelinkStatus.parse(body['status']);
  }
}
