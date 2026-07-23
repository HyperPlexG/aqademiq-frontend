// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UserProfile {

 String get name; String get email; String? get gender; DateTime? get dateOfBirth; String? get health; String? get university; String? get program;// Preset avatar choice (0–7), persisted server-side as `avatar_index`.
 int get avatarIndex;
/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserProfileCopyWith<UserProfile> get copyWith => _$UserProfileCopyWithImpl<UserProfile>(this as UserProfile, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserProfile&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.dateOfBirth, dateOfBirth) || other.dateOfBirth == dateOfBirth)&&(identical(other.health, health) || other.health == health)&&(identical(other.university, university) || other.university == university)&&(identical(other.program, program) || other.program == program)&&(identical(other.avatarIndex, avatarIndex) || other.avatarIndex == avatarIndex));
}


@override
int get hashCode => Object.hash(runtimeType,name,email,gender,dateOfBirth,health,university,program,avatarIndex);

@override
String toString() {
  return 'UserProfile(name: $name, email: $email, gender: $gender, dateOfBirth: $dateOfBirth, health: $health, university: $university, program: $program, avatarIndex: $avatarIndex)';
}


}

/// @nodoc
abstract mixin class $UserProfileCopyWith<$Res>  {
  factory $UserProfileCopyWith(UserProfile value, $Res Function(UserProfile) _then) = _$UserProfileCopyWithImpl;
@useResult
$Res call({
 String name, String email, String? gender, DateTime? dateOfBirth, String? health, String? university, String? program, int avatarIndex
});




}
/// @nodoc
class _$UserProfileCopyWithImpl<$Res>
    implements $UserProfileCopyWith<$Res> {
  _$UserProfileCopyWithImpl(this._self, this._then);

  final UserProfile _self;
  final $Res Function(UserProfile) _then;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? email = null,Object? gender = freezed,Object? dateOfBirth = freezed,Object? health = freezed,Object? university = freezed,Object? program = freezed,Object? avatarIndex = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as String?,dateOfBirth: freezed == dateOfBirth ? _self.dateOfBirth : dateOfBirth // ignore: cast_nullable_to_non_nullable
as DateTime?,health: freezed == health ? _self.health : health // ignore: cast_nullable_to_non_nullable
as String?,university: freezed == university ? _self.university : university // ignore: cast_nullable_to_non_nullable
as String?,program: freezed == program ? _self.program : program // ignore: cast_nullable_to_non_nullable
as String?,avatarIndex: null == avatarIndex ? _self.avatarIndex : avatarIndex // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UserProfile].
extension UserProfilePatterns on UserProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserProfile value)  $default,){
final _that = this;
switch (_that) {
case _UserProfile():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserProfile value)?  $default,){
final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String email,  String? gender,  DateTime? dateOfBirth,  String? health,  String? university,  String? program,  int avatarIndex)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that.name,_that.email,_that.gender,_that.dateOfBirth,_that.health,_that.university,_that.program,_that.avatarIndex);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String email,  String? gender,  DateTime? dateOfBirth,  String? health,  String? university,  String? program,  int avatarIndex)  $default,) {final _that = this;
switch (_that) {
case _UserProfile():
return $default(_that.name,_that.email,_that.gender,_that.dateOfBirth,_that.health,_that.university,_that.program,_that.avatarIndex);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String email,  String? gender,  DateTime? dateOfBirth,  String? health,  String? university,  String? program,  int avatarIndex)?  $default,) {final _that = this;
switch (_that) {
case _UserProfile() when $default != null:
return $default(_that.name,_that.email,_that.gender,_that.dateOfBirth,_that.health,_that.university,_that.program,_that.avatarIndex);case _:
  return null;

}
}

}

/// @nodoc


class _UserProfile implements UserProfile {
  const _UserProfile({required this.name, required this.email, this.gender, this.dateOfBirth, this.health, this.university, this.program, this.avatarIndex = 0});
  

@override final  String name;
@override final  String email;
@override final  String? gender;
@override final  DateTime? dateOfBirth;
@override final  String? health;
@override final  String? university;
@override final  String? program;
// Preset avatar choice (0–7), persisted server-side as `avatar_index`.
@override@JsonKey() final  int avatarIndex;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserProfileCopyWith<_UserProfile> get copyWith => __$UserProfileCopyWithImpl<_UserProfile>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserProfile&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.dateOfBirth, dateOfBirth) || other.dateOfBirth == dateOfBirth)&&(identical(other.health, health) || other.health == health)&&(identical(other.university, university) || other.university == university)&&(identical(other.program, program) || other.program == program)&&(identical(other.avatarIndex, avatarIndex) || other.avatarIndex == avatarIndex));
}


@override
int get hashCode => Object.hash(runtimeType,name,email,gender,dateOfBirth,health,university,program,avatarIndex);

@override
String toString() {
  return 'UserProfile(name: $name, email: $email, gender: $gender, dateOfBirth: $dateOfBirth, health: $health, university: $university, program: $program, avatarIndex: $avatarIndex)';
}


}

/// @nodoc
abstract mixin class _$UserProfileCopyWith<$Res> implements $UserProfileCopyWith<$Res> {
  factory _$UserProfileCopyWith(_UserProfile value, $Res Function(_UserProfile) _then) = __$UserProfileCopyWithImpl;
@override @useResult
$Res call({
 String name, String email, String? gender, DateTime? dateOfBirth, String? health, String? university, String? program, int avatarIndex
});




}
/// @nodoc
class __$UserProfileCopyWithImpl<$Res>
    implements _$UserProfileCopyWith<$Res> {
  __$UserProfileCopyWithImpl(this._self, this._then);

  final _UserProfile _self;
  final $Res Function(_UserProfile) _then;

/// Create a copy of UserProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? email = null,Object? gender = freezed,Object? dateOfBirth = freezed,Object? health = freezed,Object? university = freezed,Object? program = freezed,Object? avatarIndex = null,}) {
  return _then(_UserProfile(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,gender: freezed == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as String?,dateOfBirth: freezed == dateOfBirth ? _self.dateOfBirth : dateOfBirth // ignore: cast_nullable_to_non_nullable
as DateTime?,health: freezed == health ? _self.health : health // ignore: cast_nullable_to_non_nullable
as String?,university: freezed == university ? _self.university : university // ignore: cast_nullable_to_non_nullable
as String?,program: freezed == program ? _self.program : program // ignore: cast_nullable_to_non_nullable
as String?,avatarIndex: null == avatarIndex ? _self.avatarIndex : avatarIndex // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
