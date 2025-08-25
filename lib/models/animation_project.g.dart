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
    return AnimationProject(
      name: fields[0] as String,
      frames: (fields[1] as List).cast<Frame>(),
      paths: (fields[2] as List).cast<TransitionPaths>(),
    );
  }

  @override
  void write(BinaryWriter writer, AnimationProject obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.frames)
      ..writeByte(2)
      ..write(obj.paths);
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
