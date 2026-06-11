import 'package:event_app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows login form', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Giriş Yap'), findsWidgets);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Şifre'), findsOneWidget);
    expect(find.text('Hesabın yok mu? Kayıt ol'), findsOneWidget);
  });
}
