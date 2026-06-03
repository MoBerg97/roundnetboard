// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'animation_project.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AnimationProjectAdapter extends TypeAdapter<AnimationProject> {
  @override
  final int typeId = 3;

  @override
  AnimationProject read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final dynamic rawProjectType = fields[4];
    final int projectTypeIndex =
        rawProjectType is int ? rawProjectType : int.tryParse('${rawProjectType ?? ''}') ?? 0;
    return AnimationProject(
      name: fields[0] as String,
      frames: (fields[1] as List).cast<Frame>(),
      settings: fields[3] as Settings?,
      customCourtElements: (fields[5] as List?)?.cast<CourtElement>(),
    )..projectTypeIndex = projectTypeIndex;
  }

  @override
  void write(BinaryWriter writer, AnimationProject obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.frames)
      ..writeByte(3)
      ..write(obj.settings)
      ..writeByte(4)
      ..write(obj.projectTypeIndex)
      ..writeByte(5)
      ..write(obj.customCourtElements);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnimationProjectAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
