import 'package:flutter_test/flutter_test.dart';
import 'package:qtv/main.dart';

void main() {
  testWidgets('QtvApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const QtvApp());
    expect(find.text('QTV'), findsWidgets);
  });
}
