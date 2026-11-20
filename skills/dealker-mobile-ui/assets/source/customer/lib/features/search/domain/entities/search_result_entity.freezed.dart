// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_result_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SearchResultEntity {
  List<ProductEntity> get products;
  List<ProductEntity> get suggestions;
  int get total;
  PaginationEntity get pagination;

  /// Create a copy of SearchResultEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SearchResultEntityCopyWith<SearchResultEntity> get copyWith =>
      _$SearchResultEntityCopyWithImpl<SearchResultEntity>(
          this as SearchResultEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SearchResultEntity &&
            const DeepCollectionEquality().equals(other.products, products) &&
            const DeepCollectionEquality()
                .equals(other.suggestions, suggestions) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.pagination, pagination) ||
                other.pagination == pagination));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(products),
      const DeepCollectionEquality().hash(suggestions),
      total,
      pagination);

  @override
  String toString() {
    return 'SearchResultEntity(products: $products, suggestions: $suggestions, total: $total, pagination: $pagination)';
  }
}

/// @nodoc
abstract mixin class $SearchResultEntityCopyWith<$Res> {
  factory $SearchResultEntityCopyWith(
          SearchResultEntity value, $Res Function(SearchResultEntity) _then) =
      _$SearchResultEntityCopyWithImpl;
  @useResult
  $Res call(
      {List<ProductEntity> products,
      List<ProductEntity> suggestions,
      int total,
      PaginationEntity pagination});
}

/// @nodoc
class _$SearchResultEntityCopyWithImpl<$Res>
    implements $SearchResultEntityCopyWith<$Res> {
  _$SearchResultEntityCopyWithImpl(this._self, this._then);

  final SearchResultEntity _self;
  final $Res Function(SearchResultEntity) _then;

  /// Create a copy of SearchResultEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? products = null,
    Object? suggestions = null,
    Object? total = null,
    Object? pagination = null,
  }) {
    return _then(_self.copyWith(
      products: null == products
          ? _self.products
          : products // ignore: cast_nullable_to_non_nullable
              as List<ProductEntity>,
      suggestions: null == suggestions
          ? _self.suggestions
          : suggestions // ignore: cast_nullable_to_non_nullable
              as List<ProductEntity>,
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      pagination: null == pagination
          ? _self.pagination
          : pagination // ignore: cast_nullable_to_non_nullable
              as PaginationEntity,
    ));
  }
}

/// Adds pattern-matching-related methods to [SearchResultEntity].
extension SearchResultEntityPatterns on SearchResultEntity {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_SearchResultEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SearchResultEntity() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_SearchResultEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchResultEntity():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_SearchResultEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchResultEntity() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            List<ProductEntity> products,
            List<ProductEntity> suggestions,
            int total,
            PaginationEntity pagination)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SearchResultEntity() when $default != null:
        return $default(
            _that.products, _that.suggestions, _that.total, _that.pagination);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            List<ProductEntity> products,
            List<ProductEntity> suggestions,
            int total,
            PaginationEntity pagination)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchResultEntity():
        return $default(
            _that.products, _that.suggestions, _that.total, _that.pagination);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            List<ProductEntity> products,
            List<ProductEntity> suggestions,
            int total,
            PaginationEntity pagination)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SearchResultEntity() when $default != null:
        return $default(
            _that.products, _that.suggestions, _that.total, _that.pagination);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _SearchResultEntity implements SearchResultEntity {
  const _SearchResultEntity(
      {final List<ProductEntity> products = const <ProductEntity>[],
      final List<ProductEntity> suggestions = const <ProductEntity>[],
      this.total = 0,
      this.pagination =
          const PaginationEntity(page: 0, limit: 0, total: 0, totalPages: 0)})
      : _products = products,
        _suggestions = suggestions;

  final List<ProductEntity> _products;
  @override
  @JsonKey()
  List<ProductEntity> get products {
    if (_products is EqualUnmodifiableListView) return _products;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_products);
  }

  final List<ProductEntity> _suggestions;
  @override
  @JsonKey()
  List<ProductEntity> get suggestions {
    if (_suggestions is EqualUnmodifiableListView) return _suggestions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_suggestions);
  }

  @override
  @JsonKey()
  final int total;
  @override
  @JsonKey()
  final PaginationEntity pagination;

  /// Create a copy of SearchResultEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SearchResultEntityCopyWith<_SearchResultEntity> get copyWith =>
      __$SearchResultEntityCopyWithImpl<_SearchResultEntity>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SearchResultEntity &&
            const DeepCollectionEquality().equals(other._products, _products) &&
            const DeepCollectionEquality()
                .equals(other._suggestions, _suggestions) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.pagination, pagination) ||
                other.pagination == pagination));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_products),
      const DeepCollectionEquality().hash(_suggestions),
      total,
      pagination);

  @override
  String toString() {
    return 'SearchResultEntity(products: $products, suggestions: $suggestions, total: $total, pagination: $pagination)';
  }
}

/// @nodoc
abstract mixin class _$SearchResultEntityCopyWith<$Res>
    implements $SearchResultEntityCopyWith<$Res> {
  factory _$SearchResultEntityCopyWith(
          _SearchResultEntity value, $Res Function(_SearchResultEntity) _then) =
      __$SearchResultEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {List<ProductEntity> products,
      List<ProductEntity> suggestions,
      int total,
      PaginationEntity pagination});
}

/// @nodoc
class __$SearchResultEntityCopyWithImpl<$Res>
    implements _$SearchResultEntityCopyWith<$Res> {
  __$SearchResultEntityCopyWithImpl(this._self, this._then);

  final _SearchResultEntity _self;
  final $Res Function(_SearchResultEntity) _then;

  /// Create a copy of SearchResultEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? products = null,
    Object? suggestions = null,
    Object? total = null,
    Object? pagination = null,
  }) {
    return _then(_SearchResultEntity(
      products: null == products
          ? _self._products
          : products // ignore: cast_nullable_to_non_nullable
              as List<ProductEntity>,
      suggestions: null == suggestions
          ? _self._suggestions
          : suggestions // ignore: cast_nullable_to_non_nullable
              as List<ProductEntity>,
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
      pagination: null == pagination
          ? _self.pagination
          : pagination // ignore: cast_nullable_to_non_nullable
              as PaginationEntity,
    ));
  }
}

// dart format on
