// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipient_search_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RecipientSearchNotifier)
const recipientSearchProvider = RecipientSearchNotifierProvider._();

final class RecipientSearchNotifierProvider extends $AsyncNotifierProvider<
    RecipientSearchNotifier, List<WalletRecipientEntity>> {
  const RecipientSearchNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'recipientSearchProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$recipientSearchNotifierHash();

  @$internal
  @override
  RecipientSearchNotifier create() => RecipientSearchNotifier();
}

String _$recipientSearchNotifierHash() =>
    r'909332994f65087762db960ee6cc238978cd7544';

abstract class _$RecipientSearchNotifier
    extends $AsyncNotifier<List<WalletRecipientEntity>> {
  FutureOr<List<WalletRecipientEntity>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<List<WalletRecipientEntity>>,
        List<WalletRecipientEntity>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<List<WalletRecipientEntity>>,
            List<WalletRecipientEntity>>,
        AsyncValue<List<WalletRecipientEntity>>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
