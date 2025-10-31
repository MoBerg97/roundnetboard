// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'frame.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FrameAdapter extends TypeAdapter<Frame> {
  @override
  final int typeId = 1;

  @override
  Frame read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Frame(
      p1: fields[0] as Offset,
      p2: fields[1] as Offset,
      p3: fields[2] as Offset,
      p4: fields[3] as Offset,
      ball: fields[4] as Offset,
      p1Rotation: fields[5] as double,
      p2Rotation: fields[6] as double,
      p3Rotation: fields[7] as double,
      p4Rotation: fields[8] as double,
      p1PathPoints: (fields[9] as List?)?.cast<Offset>(),
      p2PathPoints: (fields[10] as List?)?.cast<Offset>(),
      p3PathPoints: (fields[11] as List?)?.cast<Offset>(),
      p4PathPoints: (fields[12] as List?)?.cast<Offset>(),
      ballPathPoints: (fields[13] as List?)?.cast<Offset>(),
      ballHitT: fields[14] as double?,
      ballSet: fields[15] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, Frame obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.p1)
      ..writeByte(1)
      ..write(obj.p2)
      ..writeByte(2)
      ..write(obj.p3)
      ..writeByte(3)
      ..write(obj.p4)
      ..writeByte(4)
      ..write(obj.ball)
      ..writeByte(5)
      ..write(obj.p1Rotation)
      ..writeByte(6)
      ..write(obj.p2Rotation)
      ..writeByte(7)
      ..write(obj.p3Rotation)
      ..writeByte(8)
      ..write(obj.p4Rotation)
      ..writeByte(9)
      ..write(obj.p1PathPoints)
      ..writeByte(10)
      ..write(obj.p2PathPoints)
      ..writeByte(11)
      ..write(obj.p3PathPoints)
      ..writeByte(12)
      ..write(obj.p4PathPoints)
      ..writeByte(13)
      ..write(obj.ballPathPoints)
      ..writeByte(14)
      ..write(obj.ballHitT)
      ..writeByte(15)
      ..write(obj.ballSet);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FrameAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
