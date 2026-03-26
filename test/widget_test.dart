import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:audiokit/main.dart';

void main() {
  testWidgets('AudioKit app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const AudioKitApp());

    // Verify the app title and tabs are present.
    expect(find.text('AudioKit'), findsOneWidget);
    expect(find.text('Video to Audio'), findsOneWidget);
    expect(find.text('Audio Merger'), findsOneWidget);
  });
}
