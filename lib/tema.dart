import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

/// Sıcak, sade aile teması: deniz yeşili ana renk, şeftali vurgu.
class Renk {
  static const ana = Color(0xFF2A9D8F);
  static const anaKoyu = Color(0xFF1F7A6F);
  static const anaAcik = Color(0xFFE3F4F1);
  static const vurgu = Color(0xFFF4A261);
  static const vurguAcik = Color(0xFFFDEBDC);

  static const zemin = Color(0xFFF6F5F1);
  static const kart = Colors.white;
  static const cizgi = Color(0xFFE7E5DF);
  static const yazi = Color(0xFF263238);
  static const soluk = Color(0xFF6B7280);

  static const yesil = Color(0xFF15803D);
  static const yesilAcik = Color(0xFFDCFCE7);
  static const mavi = Color(0xFF1D4ED8);
  static const maviAcik = Color(0xFFDBEAFE);
  static const mor = Color(0xFF7C3AED);
  static const morAcik = Color(0xFFEDE9FE);
  static const kirmizi = Color(0xFFDC2626);
  static const kirmiziAcik = Color(0xFFFEE2E2);
  static const gri = Color(0xFF9CA3AF);
}

ThemeData temaOlustur() {
  final cs = ColorScheme.fromSeed(seedColor: Renk.ana).copyWith(
    primary: Renk.ana,
    onPrimary: Colors.white,
    primaryContainer: Renk.anaAcik,
    onPrimaryContainer: Renk.anaKoyu,
    secondary: Renk.vurgu,
    secondaryContainer: Renk.vurguAcik,
    surface: Renk.kart,
    onSurface: Renk.yazi,
    error: Renk.kirmizi,
  );
  final kenar = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Color(0xFFD6D3CB)),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: Renk.zemin,
    appBarTheme: const AppBarTheme(
      backgroundColor: Renk.ana,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle:
          TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: kenar,
      enabledBorder: kenar,
      focusedBorder:
          kenar.copyWith(borderSide: const BorderSide(color: Renk.ana, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Renk.anaAcik,
      height: 66,
    ),
    chipTheme: const ChipThemeData(showCheckmark: false),
  );
}

void bildir(BuildContext context, String yazi) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(yazi)));
}

String hataYazisi(Object e) {
  if (e is String) return e;
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-email':
        return 'E-posta adresi geçersiz.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta ya da şifre hatalı.';
      case 'email-already-in-use':
        return 'Bu e-postayla zaten hesap var. Giriş yapmayı deneyin.';
      case 'weak-password':
        return 'Şifre çok zayıf, en az 6 karakter olmalı.';
      case 'network-request-failed':
        return 'İnternet bağlantısı yok.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı, biraz sonra tekrar deneyin.';
    }
    return e.message ?? 'Giriş yapılamadı (${e.code}).';
  }
  if (e is FirebaseException) {
    if (e.code == 'permission-denied') return 'Bu işlem için yetkiniz yok.';
    if (e.code == 'unavailable') return 'Sunucuya ulaşılamadı. İnterneti kontrol edin.';
    return e.message ?? 'Bir hata oluştu (${e.code}).';
  }
  return 'Bir hata oluştu: $e';
}

/// Beyaz kart; isteğe bağlı başlık ve sağda bir düğme.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.baslik,
    this.sag,
    this.padding = const EdgeInsets.all(16),
    this.renk = Renk.kart,
  });

  final Widget child;
  final String? baslik;
  final Widget? sag;
  final EdgeInsets padding;
  final Color renk;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: padding,
      decoration: BoxDecoration(
        color: renk,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Renk.cizgi),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (baslik != null || sag != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(baslik ?? '',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700, color: Renk.yazi)),
                ),
                if (sag != null) sag!,
              ],
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

class Buton extends StatelessWidget {
  const Buton({
    super.key,
    required this.yazi,
    required this.onTap,
    this.ikon,
    this.mesgul = false,
    this.ikincil = false,
  });

  final String yazi;
  final VoidCallback? onTap;
  final IconData? ikon;
  final bool mesgul;
  final bool ikincil;

  @override
  Widget build(BuildContext context) {
    final icerik = mesgul
        ? const SizedBox(
            width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ikon != null) ...[Icon(ikon, size: 20), const SizedBox(width: 8)],
              Flexible(child: Text(yazi, overflow: TextOverflow.ellipsis)),
            ],
          );
    final basla = mesgul ? null : onTap;
    return ikincil
        ? OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(64, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: basla,
            child: icerik)
        : FilledButton(onPressed: basla, child: icerik);
  }
}

/// Liste boşken gösterilen açıklama.
class BosDurum extends StatelessWidget {
  const BosDurum({super.key, required this.ikon, required this.yazi});
  final IconData ikon;
  final String yazi;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(
          children: [
            Icon(ikon, size: 44, color: Renk.gri),
            const SizedBox(height: 10),
            Text(yazi,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Renk.soluk, fontSize: 14.5)),
          ],
        ),
      );
}

/// Küçük renkli etiket.
class Etiket extends StatelessWidget {
  const Etiket(this.yazi, {super.key, this.renk = Renk.anaKoyu, this.zemin = Renk.anaAcik});
  final String yazi;
  final Color renk;
  final Color zemin;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: zemin, borderRadius: BorderRadius.circular(20)),
        child: Text(yazi,
            style: TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

/// Yatay ilerleme çubuğu (0..1).
class Cubuk extends StatelessWidget {
  const Cubuk({super.key, required this.oran, this.renk = Renk.ana, this.yukseklik = 10});
  final double oran;
  final Color renk;
  final double yukseklik;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(yukseklik),
        child: LinearProgressIndicator(
          value: oran.isNaN ? 0 : oran.clamp(0.0, 1.0).toDouble(),
          minHeight: yukseklik,
          color: renk,
          backgroundColor: Renk.cizgi,
        ),
      );
}

Future<bool> onayla(BuildContext context, String baslik, String metin,
    {String evet = 'Sil'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(baslik),
      content: Text(metin),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(evet)),
      ],
    ),
  );
  return r == true;
}
