// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bounce_point.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BouncePointAdapter extends TypeAdapter<BouncePoint> {
  @override
  final int typeId = 7;

  @override
  BouncePoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BouncePoint(
      position: fields[0] as InvalidType,
      minScale: fields[1] as double,
      endScale: fields[2] as double,
      starDurationMs: fields[3] as int,
      showStar: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, BouncePoint obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.position)
      ..writeByte(1)
      ..write(obj.minScale)
      ..writeByte(2)
      ..write(obj.endScale)
      ..writeByte(3)
      ..write(obj.starDurationMs)
      ..writeByte(4)
      ..write(obj.showStar);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BouncePointAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
