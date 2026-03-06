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
    final fields = <int, dynamic>{for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read()};
    return Settings(
      playbackSpeed: fields[0] as double,
      outerCircleRadiusCm: fields[1] as double,
      innerCircleRadiusCm: fields[2] as double,
      netCircleRadiusCm: fields[3] as double,
      outerBoundsRadiusCm: fields[4] as double,
      referenceRadiusCm: fields[5] as double,
      showPreviousFrameLines: fields[6] as bool,
      showPathControlPoints: fields[7] as bool,
      objectScaleMultiplier: fields[8] as double,
      annotationsAboveObjects: fields[10] == null ? false : fields[10] as bool,
      serveZoneFactor: fields[9] == null ? 1.3 : fields[9] as double,
      courtBackgroundColorValue: fields[11] as int?,
      ballSectorRadiusCm: fields[12] == null ? 1000.0 : fields[12] as double,
      handDrawnAnnotations: fields[13] == null ? false : fields[13] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Settings obj) {
    writer
      ..writeByte(14)
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
      ..write(obj.referenceRadiusCm)
      ..writeByte(6)
      ..write(obj.showPreviousFrameLines)
      ..writeByte(7)
      ..write(obj.showPathControlPoints)
      ..writeByte(8)
      ..write(obj.objectScaleMultiplier)
      ..writeByte(10)
      ..write(obj.annotationsAboveObjects)
      ..writeByte(9)
      ..write(obj.serveZoneFactor)
      ..writeByte(11)
      ..write(obj.courtBackgroundColorValue)
      ..writeByte(12)
      ..write(obj.ballSectorRadiusCm)
      ..writeByte(13)
      ..write(obj.handDrawnAnnotations);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SettingsAdapter && runtimeType == other.runtimeType && typeId == other.typeId;
}
