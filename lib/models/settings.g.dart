// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SettingsAdapter extends TypeAdapter<Settings> {
  @override
  final int typeId = 4;

  @override
  Settings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Settings(
      playbackSpeed: fields[0] as double,
      outerCircleRadius: fields[1] as double,
      innerCircleRadius: fields[2] as double,
      netCircleRadius: fields[3] as double,
    )..outerBoundsRadius = fields[4] as double;
  }

  @override
  void write(BinaryWriter writer, Settings obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.playbackSpeed)
      ..writeByte(1)
      ..write(obj.outerCircleRadius)
      ..writeByte(2)
      ..write(obj.innerCircleRadius)
      ..writeByte(3)
      ..write(obj.netCircleRadius)
      ..writeByte(4)
      ..write(obj.outerBoundsRadius);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
