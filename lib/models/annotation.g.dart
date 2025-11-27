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
    )..colorValue = fields[4] as int;
  }

  @override
  void write(BinaryWriter writer, Annotation obj) {
    writer
      ..writeByte(3)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.colorValue)
      ..writeByte(5)
      ..write(obj.points);
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
