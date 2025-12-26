// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'court_element.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CourtElementAdapter extends TypeAdapter<CourtElement> {
  @override
  final int typeId = 12;

  @override
  CourtElement read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CourtElement(
      position: fields[1] as Offset,
      radius: fields[2] as double?,
      endPosition: fields[3] as Offset?,
      strokeWidth: fields[5] as double,
      isVisible: (fields[6] as bool?) ?? true,
    )
      ..typeIndex = fields[0] as int
      ..colorValue = fields[4] as int;
  }

  @override
  void write(BinaryWriter writer, CourtElement obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.typeIndex)
      ..writeByte(1)
      ..write(obj.position)
      ..writeByte(2)
      ..write(obj.radius)
      ..writeByte(3)
      ..write(obj.endPosition)
      ..writeByte(4)
      ..write(obj.colorValue)
      ..writeByte(5)
      ..write(obj.strokeWidth)
      ..writeByte(6)
      ..write(obj.isVisible);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourtElementAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
