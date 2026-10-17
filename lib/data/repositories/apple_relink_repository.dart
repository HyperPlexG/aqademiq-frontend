import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env/env.dart';
import '../../core/network/dio_client.dart';
import '../models/apple_relink_status.dart';
import '../sources/apple_relink_source.dart';

class AppleRelinkRepository {
  AppleRelinkRepository(this._source);
  final AppleRelinkSource _source;

  Future<bool> needed() => _source.needed();

  Future<AppleRelinkStatus> relink({
    required String identityToken,
    required String nonce,
  }) =>
      _source.relink(identityToken: identityToken, nonce: nonce);
}

final appleRelinkRepositoryProvider = Provider<AppleRelinkRepository>((ref) {
  final source = Env.useMocks
      ? MockAppleRelinkSource()
      : ApiAppleRelinkSource(ref.watch(dioProvider));
  return AppleRelinkRepository(source);
});
