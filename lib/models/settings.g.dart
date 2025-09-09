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
      outerCircleRadiusCm: fields[1] as double,
      innerCircleRadiusCm: fields[2] as double,
      netCircleRadiusCm: fields[3] as double,
      outerBoundsRadiusCm: fields[4] as double,
      referenceRadiusCm: fields[5] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Settings obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.playbackSpeed)
      ..writeByte(1)
      ..write(obj.outerCircleRadiusCm)
      ..writeByte(2)
      ..write(obj.innerCircleRadiusCm)
      ..writeByte(3)
      ..write(obj.netCircleRadiusCm)
      ..writeByte(4)
      ..write(obj.outerBoundsRadiusCm)
      ..writeByte(5)
      ..write(obj.referenceRadiusCm);
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
