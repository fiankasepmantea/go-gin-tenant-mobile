import 'package:go_gin_tenant_mobile/core/api/tokens.dart';

/// A [TokenStore] in memory for tests.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.tokens]);

  Tokens? tokens;
  int clears = 0;

  @override
  Future<Tokens?> read() async => tokens;

  @override
  Future<void> write(Tokens value) async => tokens = value;

  @override
  Future<void> clear() async {
    clears++;
    tokens = null;
  }
}
