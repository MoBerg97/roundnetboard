// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'annotation.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AnnotationAdapter extends TypeAdapter<Annotation> {
  @override
  final int typeId = 2;

  @override
  Annotation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Annotation(
      type: fields[3] as AnnotationType,
      points: (fields[5] as List).cast<Offset>(),
      filled: fields[6] as bool,
      strokeWidthCm: fields[7] as double,
      circleAnnotationId: fields[8] as String?,
      startAngle: fields[9] as double?,
      endAngle: fields[10] as double?,
      id: fields[11] as String?,
    )..colorValue = fields[4] as int;
  }

  @override
  void write(BinaryWriter writer, Annotation obj) {
    writer
      ..writeByte(9)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.colorValue)
      ..writeByte(5)
      ..write(obj.points)
      ..writeByte(6)
      ..write(obj.filled)
      ..writeByte(7)
      ..write(obj.strokeWidthCm)
      ..writeByte(8)
      ..write(obj.circleAnnotationId)
      ..writeByte(9)
      ..write(obj.startAngle)
      ..writeByte(10)
      ..write(obj.endAngle)
      ..writeByte(11)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnnotationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AnnotationTypeAdapter extends TypeAdapter<AnnotationType> {
  @override
  final int typeId = 5;

  @override
  AnnotationType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AnnotationType.line;
      case 1:
        return AnnotationType.circle;
      case 2:
        return AnnotationType.rectangle;
      case 3:
        return AnnotationType.sector;
      default:
        return AnnotationType.line;
    }
  }

  @override
  void write(BinaryWriter writer, AnnotationType obj) {
    switch (obj) {
      case AnnotationType.line:
        writer.writeByte(0);
        break;
      case AnnotationType.circle:
        writer.writeByte(1);
        break;
      case AnnotationType.rectangle:
        writer.writeByte(2);
        break;
      case AnnotationType.sector:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnnotationTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
