// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ball.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BallAdapter extends TypeAdapter<Ball> {
  @override
  final int typeId = 11;

  @override
  Ball read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Ball(
      position: fields[0] as Offset,
      pathPoints: (fields[1] as List?)?.cast<Offset>(),
      hitT: fields[2] as double?,
      isSet: fields[3] as bool?,
      id: fields[5] as String?,
    )..colorValue = fields[4] as int;
  }

  @override
  void write(BinaryWriter writer, Ball obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.position)
      ..writeByte(1)
      ..write(obj.pathPoints)
      ..writeByte(2)
      ..write(obj.hitT)
      ..writeByte(3)
      ..write(obj.isSet)
      ..writeByte(4)
      ..write(obj.colorValue)
      ..writeByte(5)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BallAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
