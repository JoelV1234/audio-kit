import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:audiokit/main.dart';

void main() {
  testWidgets('AudioKit app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const AudioKitApp());

    // Verify the tabs are present.
    expect(find.text('Video to Audio'), findsWidgets);
    expect(find.text('Audio Merger'), findsWidgets);
  });
}
