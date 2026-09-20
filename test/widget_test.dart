import 'package:flutter_test/flutter_test.dart';
import 'package:bitnet_mobile/main.dart';

void main() {
  testWidgets('BitNetApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BitNetApp());
    expect(find.text('BitNet AI'), findsWidgets);
    expect(find.text('Чат'), findsOneWidget);
    expect(find.text('Модели'), findsOneWidget);
    expect(find.text('Мониторинг'), findsOneWidget);
    expect(find.text('Настройки'), findsOneWidget);
  });
}
