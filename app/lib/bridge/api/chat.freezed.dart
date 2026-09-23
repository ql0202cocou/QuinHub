// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ChatEventDto {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatEventDto);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ChatEventDto()';
}


}

/// @nodoc
class $ChatEventDtoCopyWith<$Res>  {
$ChatEventDtoCopyWith(ChatEventDto _, $Res Function(ChatEventDto) __);
}


/// Adds pattern-matching-related methods to [ChatEventDto].
extension ChatEventDtoPatterns on ChatEventDto {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ChatEventDto_Delta value)?  delta,TResult Function( ChatEventDto_ReasoningDelta value)?  reasoningDelta,TResult Function( ChatEventDto_Usage value)?  usage,TResult Function( ChatEventDto_Done value)?  done,TResult Function( ChatEventDto_Error value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ChatEventDto_Delta() when delta != null:
return delta(_that);case ChatEventDto_ReasoningDelta() when reasoningDelta != null:
return reasoningDelta(_that);case ChatEventDto_Usage() when usage != null:
return usage(_that);case ChatEventDto_Done() when done != null:
return done(_that);case ChatEventDto_Error() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ChatEventDto_Delta value)  delta,required TResult Function( ChatEventDto_ReasoningDelta value)  reasoningDelta,required TResult Function( ChatEventDto_Usage value)  usage,required TResult Function( ChatEventDto_Done value)  done,required TResult Function( ChatEventDto_Error value)  error,}){
final _that = this;
switch (_that) {
case ChatEventDto_Delta():
return delta(_that);case ChatEventDto_ReasoningDelta():
return reasoningDelta(_that);case ChatEventDto_Usage():
return usage(_that);case ChatEventDto_Done():
return done(_that);case ChatEventDto_Error():
return error(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ChatEventDto_Delta value)?  delta,TResult? Function( ChatEventDto_ReasoningDelta value)?  reasoningDelta,TResult? Function( ChatEventDto_Usage value)?  usage,TResult? Function( ChatEventDto_Done value)?  done,TResult? Function( ChatEventDto_Error value)?  error,}){
final _that = this;
switch (_that) {
case ChatEventDto_Delta() when delta != null:
return delta(_that);case ChatEventDto_ReasoningDelta() when reasoningDelta != null:
return reasoningDelta(_that);case ChatEventDto_Usage() when usage != null:
return usage(_that);case ChatEventDto_Done() when done != null:
return done(_that);case ChatEventDto_Error() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String text)?  delta,TResult Function( String text)?  reasoningDelta,TResult Function( BigInt input,  BigInt output)?  usage,TResult Function()?  done,TResult Function( String code,  String message)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ChatEventDto_Delta() when delta != null:
return delta(_that.text);case ChatEventDto_ReasoningDelta() when reasoningDelta != null:
return reasoningDelta(_that.text);case ChatEventDto_Usage() when usage != null:
return usage(_that.input,_that.output);case ChatEventDto_Done() when done != null:
return done();case ChatEventDto_Error() when error != null:
return error(_that.code,_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String text)  delta,required TResult Function( String text)  reasoningDelta,required TResult Function( BigInt input,  BigInt output)  usage,required TResult Function()  done,required TResult Function( String code,  String message)  error,}) {final _that = this;
switch (_that) {
case ChatEventDto_Delta():
return delta(_that.text);case ChatEventDto_ReasoningDelta():
return reasoningDelta(_that.text);case ChatEventDto_Usage():
return usage(_that.input,_that.output);case ChatEventDto_Done():
return done();case ChatEventDto_Error():
return error(_that.code,_that.message);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String text)?  delta,TResult? Function( String text)?  reasoningDelta,TResult? Function( BigInt input,  BigInt output)?  usage,TResult? Function()?  done,TResult? Function( String code,  String message)?  error,}) {final _that = this;
switch (_that) {
case ChatEventDto_Delta() when delta != null:
return delta(_that.text);case ChatEventDto_ReasoningDelta() when reasoningDelta != null:
return reasoningDelta(_that.text);case ChatEventDto_Usage() when usage != null:
return usage(_that.input,_that.output);case ChatEventDto_Done() when done != null:
return done();case ChatEventDto_Error() when error != null:
return error(_that.code,_that.message);case _:
  return null;

}
}

}

/// @nodoc


class ChatEventDto_Delta extends ChatEventDto {
  const ChatEventDto_Delta({required this.text}): super._();
  

 final  String text;

/// Create a copy of ChatEventDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatEventDto_DeltaCopyWith<ChatEventDto_Delta> get copyWith => _$ChatEventDto_DeltaCopyWithImpl<ChatEventDto_Delta>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatEventDto_Delta&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'ChatEventDto.delta(text: $text)';
}


}

/// @nodoc
abstract mixin class $ChatEventDto_DeltaCopyWith<$Res> implements $ChatEventDtoCopyWith<$Res> {
  factory $ChatEventDto_DeltaCopyWith(ChatEventDto_Delta value, $Res Function(ChatEventDto_Delta) _then) = _$ChatEventDto_DeltaCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$ChatEventDto_DeltaCopyWithImpl<$Res>
    implements $ChatEventDto_DeltaCopyWith<$Res> {
  _$ChatEventDto_DeltaCopyWithImpl(this._self, this._then);

  final ChatEventDto_Delta _self;
  final $Res Function(ChatEventDto_Delta) _then;

/// Create a copy of ChatEventDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(ChatEventDto_Delta(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ChatEventDto_ReasoningDelta extends ChatEventDto {
  const ChatEventDto_ReasoningDelta({required this.text}): super._();
  

 final  String text;

/// Create a copy of ChatEventDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatEventDto_ReasoningDeltaCopyWith<ChatEventDto_ReasoningDelta> get copyWith => _$ChatEventDto_ReasoningDeltaCopyWithImpl<ChatEventDto_ReasoningDelta>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatEventDto_ReasoningDelta&&(identical(other.text, text) || other.text == text));
}


@override
int get hashCode => Object.hash(runtimeType,text);

@override
String toString() {
  return 'ChatEventDto.reasoningDelta(text: $text)';
}


}

/// @nodoc
abstract mixin class $ChatEventDto_ReasoningDeltaCopyWith<$Res> implements $ChatEventDtoCopyWith<$Res> {
  factory $ChatEventDto_ReasoningDeltaCopyWith(ChatEventDto_ReasoningDelta value, $Res Function(ChatEventDto_ReasoningDelta) _then) = _$ChatEventDto_ReasoningDeltaCopyWithImpl;
@useResult
$Res call({
 String text
});




}
/// @nodoc
class _$ChatEventDto_ReasoningDeltaCopyWithImpl<$Res>
    implements $ChatEventDto_ReasoningDeltaCopyWith<$Res> {
  _$ChatEventDto_ReasoningDeltaCopyWithImpl(this._self, this._then);

  final ChatEventDto_ReasoningDelta _self;
  final $Res Function(ChatEventDto_ReasoningDelta) _then;

/// Create a copy of ChatEventDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? text = null,}) {
  return _then(ChatEventDto_ReasoningDelta(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ChatEventDto_Usage extends ChatEventDto {
  const ChatEventDto_Usage({required this.input, required this.output}): super._();
  

 final  BigInt input;
 final  BigInt output;

/// Create a copy of ChatEventDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatEventDto_UsageCopyWith<ChatEventDto_Usage> get copyWith => _$ChatEventDto_UsageCopyWithImpl<ChatEventDto_Usage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatEventDto_Usage&&(identical(other.input, input) || other.input == input)&&(identical(other.output, output) || other.output == output));
}


@override
int get hashCode => Object.hash(runtimeType,input,output);

@override
String toString() {
  return 'ChatEventDto.usage(input: $input, output: $output)';
}


}

/// @nodoc
abstract mixin class $ChatEventDto_UsageCopyWith<$Res> implements $ChatEventDtoCopyWith<$Res> {
  factory $ChatEventDto_UsageCopyWith(ChatEventDto_Usage value, $Res Function(ChatEventDto_Usage) _then) = _$ChatEventDto_UsageCopyWithImpl;
@useResult
$Res call({
 BigInt input, BigInt output
});




}
/// @nodoc
class _$ChatEventDto_UsageCopyWithImpl<$Res>
    implements $ChatEventDto_UsageCopyWith<$Res> {
  _$ChatEventDto_UsageCopyWithImpl(this._self, this._then);

  final ChatEventDto_Usage _self;
  final $Res Function(ChatEventDto_Usage) _then;

/// Create a copy of ChatEventDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? input = null,Object? output = null,}) {
  return _then(ChatEventDto_Usage(
input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as BigInt,output: null == output ? _self.output : output // ignore: cast_nullable_to_non_nullable
as BigInt,
  ));
}


}

/// @nodoc


class ChatEventDto_Done extends ChatEventDto {
  const ChatEventDto_Done(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatEventDto_Done);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ChatEventDto.done()';
}


}




/// @nodoc


class ChatEventDto_Error extends ChatEventDto {
  const ChatEventDto_Error({required this.code, required this.message}): super._();
  

 final  String code;
 final  String message;

/// Create a copy of ChatEventDto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatEventDto_ErrorCopyWith<ChatEventDto_Error> get copyWith => _$ChatEventDto_ErrorCopyWithImpl<ChatEventDto_Error>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatEventDto_Error&&(identical(other.code, code) || other.code == code)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,code,message);

@override
String toString() {
  return 'ChatEventDto.error(code: $code, message: $message)';
}


}

/// @nodoc
abstract mixin class $ChatEventDto_ErrorCopyWith<$Res> implements $ChatEventDtoCopyWith<$Res> {
  factory $ChatEventDto_ErrorCopyWith(ChatEventDto_Error value, $Res Function(ChatEventDto_Error) _then) = _$ChatEventDto_ErrorCopyWithImpl;
@useResult
$Res call({
 String code, String message
});




}
/// @nodoc
class _$ChatEventDto_ErrorCopyWithImpl<$Res>
    implements $ChatEventDto_ErrorCopyWith<$Res> {
  _$ChatEventDto_ErrorCopyWithImpl(this._self, this._then);

  final ChatEventDto_Error _self;
  final $Res Function(ChatEventDto_Error) _then;

/// Create a copy of ChatEventDto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? code = null,Object? message = null,}) {
  return _then(ChatEventDto_Error(
code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
