import 'package:flutter/material.dart';

double cmToLogical(double cm, Size screenSize) {
  const double padding = 50;
  const double appBarHeight = kToolbarHeight;
  const double timelineHeight = 120;
  final usableHeight = screenSize.height - appBarHeight - timelineHeight;
  final usableWidth = screenSize.width;
  final halfMinScreen = (usableHeight < usableWidth ? usableHeight : usableWidth) / 2 - padding;
  return cm * (halfMinScreen / 260.0);
}

double logicalToCm(double logical, Size screenSize) {
  const double padding = 50;
  const double appBarHeight = kToolbarHeight;
  const double timelineHeight = 120;
  final usableHeight = screenSize.height - appBarHeight - timelineHeight;
  final usableWidth = screenSize.width;
  final halfMinScreen = (usableHeight < usableWidth ? usableHeight : usableWidth) / 2 - padding;
  return logical * (260.0 / halfMinScreen);
}