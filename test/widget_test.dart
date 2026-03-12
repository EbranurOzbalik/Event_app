import 'package:event_app/screens/login_screen.dart';
import 'package:event_app/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Login ekrani bos alanlarda uyari gosterir', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Giriş Yap'));
    await tester.pump();

    expect(find.text('Email ve şifre boş olamaz.'), findsOneWidget);
  });

  testWidgets('Login ekranindan kayit ekranina gecilir', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.tap(find.text('Hesabın yok mu? Kayıt ol'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
  });
}
