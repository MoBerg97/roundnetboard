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
      players: (fields[0] as List?)?.cast<Player>(),
      balls: (fields[1] as List?)?.cast<Ball>(),
      duration: fields[2] as double,
      annotations: (fields[3] as List?)?.cast<Annotation>(),
    );
  }

  @override
  void write(BinaryWriter writer, Frame obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.players)
      ..writeByte(1)
      ..write(obj.balls)
      ..writeByte(2)
      ..write(obj.duration)
      ..writeByte(3)
      ..write(obj.annotations);
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
