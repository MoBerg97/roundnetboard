// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transition_paths.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransitionPathsAdapter extends TypeAdapter<TransitionPaths> {
  @override
  final int typeId = 2;

  @override
  TransitionPaths read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransitionPaths(
      p1Ctrl: fields[0] as Offset,
      p2Ctrl: fields[1] as Offset,
      p3Ctrl: fields[2] as Offset,
      p4Ctrl: fields[3] as Offset,
      ballCtrl: fields[4] as Offset,
    );
  }

  @override
  void write(BinaryWriter writer, TransitionPaths obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.p1Ctrl)
      ..writeByte(1)
      ..write(obj.p2Ctrl)
      ..writeByte(2)
      ..write(obj.p3Ctrl)
      ..writeByte(3)
      ..write(obj.p4Ctrl)
      ..writeByte(4)
      ..write(obj.ballCtrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransitionPathsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
