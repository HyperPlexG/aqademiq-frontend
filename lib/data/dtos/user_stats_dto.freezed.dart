// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_stats_dto.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserStatsDto {

 int get streakDays;// These two are LIFETIME totals. `/v1/me/stats` sums every completed task
// and every focus session a user has ever run; it has no week filter and
// never had one. They were called `...ThisWeek` here, and the Stats screen
// showed the result under a "this week" label whenever the real weekly
// provider was still loading — a lifetime count presented as seven days.
// Named for what they are so the next person cannot make that mistake.
 int get focusMinutesLifetime; int get tasksCompletedLifetime;/// Days the student has ever been on the board. Only ever goes up, and has
/// nothing to fall short of — which is why it replaced the streak on the
/// Stats screen.
 int get totalActiveDays; List<MoodLogDto> get weekMoods;
/// Create a copy of UserStatsDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserStatsDtoCopyWith<UserStatsDto> get copyWith => _$UserStatsDtoCopyWithImpl<UserStatsDto>(this as UserStatsDto, _$identity);

  /// Serializes this UserStatsDto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserStatsDto&&(identical(other.streakDays, streakDays) || other.streakDays == streakDays)&&(identical(other.focusMinutesLifetime, focusMinutesLifetime) || other.focusMinutesLifetime == focusMinutesLifetime)&&(identical(other.tasksCompletedLifetime, tasksCompletedLifetime) || other.tasksCompletedLifetime == tasksCompletedLifetime)&&(identical(other.totalActiveDays, totalActiveDays) || other.totalActiveDays == totalActiveDays)&&const DeepCollectionEquality().equals(other.weekMoods, weekMoods));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,streakDays,focusMinutesLifetime,tasksCompletedLifetime,totalActiveDays,const DeepCollectionEquality().hash(weekMoods));

@override
String toString() {
  return 'UserStatsDto(streakDays: $streakDays, focusMinutesLifetime: $focusMinutesLifetime, tasksCompletedLifetime: $tasksCompletedLifetime, totalActiveDays: $totalActiveDays, weekMoods: $weekMoods)';
}


}

/// @nodoc
abstract mixin class $UserStatsDtoCopyWith<$Res>  {
  factory $UserStatsDtoCopyWith(UserStatsDto value, $Res Function(UserStatsDto) _then) = _$UserStatsDtoCopyWithImpl;
@useResult
$Res call({
 int streakDays, int focusMinutesLifetime, int tasksCompletedLifetime, int totalActiveDays, List<MoodLogDto> weekMoods
});




}
/// @nodoc
class _$UserStatsDtoCopyWithImpl<$Res>
    implements $UserStatsDtoCopyWith<$Res> {
  _$UserStatsDtoCopyWithImpl(this._self, this._then);

  final UserStatsDto _self;
  final $Res Function(UserStatsDto) _then;

/// Create a copy of UserStatsDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? streakDays = null,Object? focusMinutesLifetime = null,Object? tasksCompletedLifetime = null,Object? totalActiveDays = null,Object? weekMoods = null,}) {
  return _then(_self.copyWith(
streakDays: null == streakDays ? _self.streakDays : streakDays // ignore: cast_nullable_to_non_nullable
as int,focusMinutesLifetime: null == focusMinutesLifetime ? _self.focusMinutesLifetime : focusMinutesLifetime // ignore: cast_nullable_to_non_nullable
as int,tasksCompletedLifetime: null == tasksCompletedLifetime ? _self.tasksCompletedLifetime : tasksCompletedLifetime // ignore: cast_nullable_to_non_nullable
as int,totalActiveDays: null == totalActiveDays ? _self.totalActiveDays : totalActiveDays // ignore: cast_nullable_to_non_nullable
as int,weekMoods: null == weekMoods ? _self.weekMoods : weekMoods // ignore: cast_nullable_to_non_nullable
as List<MoodLogDto>,
  ));
}

}


/// Adds pattern-matching-related methods to [UserStatsDto].
extension UserStatsDtoPatterns on UserStatsDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserStatsDto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserStatsDto() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserStatsDto value)  $default,){
final _that = this;
switch (_that) {
case _UserStatsDto():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserStatsDto value)?  $default,){
final _that = this;
switch (_that) {
case _UserStatsDto() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int streakDays,  int focusMinutesLifetime,  int tasksCompletedLifetime,  int totalActiveDays,  List<MoodLogDto> weekMoods)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserStatsDto() when $default != null:
return $default(_that.streakDays,_that.focusMinutesLifetime,_that.tasksCompletedLifetime,_that.totalActiveDays,_that.weekMoods);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int streakDays,  int focusMinutesLifetime,  int tasksCompletedLifetime,  int totalActiveDays,  List<MoodLogDto> weekMoods)  $default,) {final _that = this;
switch (_that) {
case _UserStatsDto():
return $default(_that.streakDays,_that.focusMinutesLifetime,_that.tasksCompletedLifetime,_that.totalActiveDays,_that.weekMoods);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int streakDays,  int focusMinutesLifetime,  int tasksCompletedLifetime,  int totalActiveDays,  List<MoodLogDto> weekMoods)?  $default,) {final _that = this;
switch (_that) {
case _UserStatsDto() when $default != null:
return $default(_that.streakDays,_that.focusMinutesLifetime,_that.tasksCompletedLifetime,_that.totalActiveDays,_that.weekMoods);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserStatsDto implements UserStatsDto {
  const _UserStatsDto({this.streakDays = 0, this.focusMinutesLifetime = 0, this.tasksCompletedLifetime = 0, this.totalActiveDays = 0, final  List<MoodLogDto> weekMoods = const <MoodLogDto>[]}): _weekMoods = weekMoods;
  factory _UserStatsDto.fromJson(Map<String, dynamic> json) => _$UserStatsDtoFromJson(json);

@override@JsonKey() final  int streakDays;
// These two are LIFETIME totals. `/v1/me/stats` sums every completed task
// and every focus session a user has ever run; it has no week filter and
// never had one. They were called `...ThisWeek` here, and the Stats screen
// showed the result under a "this week" label whenever the real weekly
// provider was still loading — a lifetime count presented as seven days.
// Named for what they are so the next person cannot make that mistake.
@override@JsonKey() final  int focusMinutesLifetime;
@override@JsonKey() final  int tasksCompletedLifetime;
/// Days the student has ever been on the board. Only ever goes up, and has
/// nothing to fall short of — which is why it replaced the streak on the
/// Stats screen.
@override@JsonKey() final  int totalActiveDays;
 final  List<MoodLogDto> _weekMoods;
@override@JsonKey() List<MoodLogDto> get weekMoods {
  if (_weekMoods is EqualUnmodifiableListView) return _weekMoods;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_weekMoods);
}


/// Create a copy of UserStatsDto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserStatsDtoCopyWith<_UserStatsDto> get copyWith => __$UserStatsDtoCopyWithImpl<_UserStatsDto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserStatsDtoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserStatsDto&&(identical(other.streakDays, streakDays) || other.streakDays == streakDays)&&(identical(other.focusMinutesLifetime, focusMinutesLifetime) || other.focusMinutesLifetime == focusMinutesLifetime)&&(identical(other.tasksCompletedLifetime, tasksCompletedLifetime) || other.tasksCompletedLifetime == tasksCompletedLifetime)&&(identical(other.totalActiveDays, totalActiveDays) || other.totalActiveDays == totalActiveDays)&&const DeepCollectionEquality().equals(other._weekMoods, _weekMoods));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,streakDays,focusMinutesLifetime,tasksCompletedLifetime,totalActiveDays,const DeepCollectionEquality().hash(_weekMoods));

@override
String toString() {
  return 'UserStatsDto(streakDays: $streakDays, focusMinutesLifetime: $focusMinutesLifetime, tasksCompletedLifetime: $tasksCompletedLifetime, totalActiveDays: $totalActiveDays, weekMoods: $weekMoods)';
}


}

/// @nodoc
abstract mixin class _$UserStatsDtoCopyWith<$Res> implements $UserStatsDtoCopyWith<$Res> {
  factory _$UserStatsDtoCopyWith(_UserStatsDto value, $Res Function(_UserStatsDto) _then) = __$UserStatsDtoCopyWithImpl;
@override @useResult
$Res call({
 int streakDays, int focusMinutesLifetime, int tasksCompletedLifetime, int totalActiveDays, List<MoodLogDto> weekMoods
});




}
/// @nodoc
class __$UserStatsDtoCopyWithImpl<$Res>
    implements _$UserStatsDtoCopyWith<$Res> {
  __$UserStatsDtoCopyWithImpl(this._self, this._then);

  final _UserStatsDto _self;
  final $Res Function(_UserStatsDto) _then;

/// Create a copy of UserStatsDto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? streakDays = null,Object? focusMinutesLifetime = null,Object? tasksCompletedLifetime = null,Object? totalActiveDays = null,Object? weekMoods = null,}) {
  return _then(_UserStatsDto(
streakDays: null == streakDays ? _self.streakDays : streakDays // ignore: cast_nullable_to_non_nullable
as int,focusMinutesLifetime: null == focusMinutesLifetime ? _self.focusMinutesLifetime : focusMinutesLifetime // ignore: cast_nullable_to_non_nullable
as int,tasksCompletedLifetime: null == tasksCompletedLifetime ? _self.tasksCompletedLifetime : tasksCompletedLifetime // ignore: cast_nullable_to_non_nullable
as int,totalActiveDays: null == totalActiveDays ? _self.totalActiveDays : totalActiveDays // ignore: cast_nullable_to_non_nullable
as int,weekMoods: null == weekMoods ? _self._weekMoods : weekMoods // ignore: cast_nullable_to_non_nullable
as List<MoodLogDto>,
  ));
}


}

// dart format on
