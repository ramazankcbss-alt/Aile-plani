import 'package:flutter/material.dart';

import '../bicim.dart';
import '../modeller.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'ortak.dart';

// --- Haftalık program -------------------------------------------------------

class ProgramFormu extends StatefulWidget {
  const ProgramFormu({super.key, required this.durum, this.oge, this.gun = 1});
  final Durum durum;
  final ProgramOgesi? oge;
  final int gun;

  @override
  State<ProgramFormu> createState() => _ProgramFormuState();
}

class _ProgramFormuState extends State<ProgramFormu> {
  late final _baslik = TextEditingController(text: widget.oge?.baslik ?? '');
  late List<int> _gunler = [widget.oge?.gun ?? widget.gun];
  late int _saat = widget.oge?.saat ?? 19 * 60;
  late int _sure = widget.oge?.sure ?? 60;
  late String _tur = widget.oge?.tur ?? 'aile';
  late List<String> _kisiler = [...?widget.oge?.kisiler];

  static const _sureler = [15, 30, 45, 60, 90, 120, 180, 240, 480];

  @override
  void dispose() {
    _baslik.dispose();
    super.dispose();
  }

  Future<void> _saatSec() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _saat ~/ 60, minute: _saat % 60),
    );
    if (t != null) setState(() => _saat = t.hour * 60 + t.minute);
  }

  Future<String?> _kaydet() async {
    final b = _baslik.text.trim();
    if (b.isEmpty) return 'Ne yapılacağını yazın.';
    if (_gunler.isEmpty) return 'En az bir gün seçin.';
    final aid = widget.durum.aid;
    final veri = {
      'saat': _saat,
      'sure': _sure,
      'baslik': b,
      'tur': _tur,
      'kisiler': _kisiler,
    };
    final o = widget.oge;
    if (o != null) {
      await Veri.kaydet(aid, 'program', o.id, {...veri, 'gun': _gunler.first});
      for (final g in _gunler.skip(1)) {
        await Veri.kaydet(aid, 'program', null, {...veri, 'gun': g});
      }
    } else {
      for (final g in _gunler) {
        await Veri.kaydet(aid, 'program', null, {...veri, 'gun': g});
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final aile = widget.durum.aile!;
    return FormSayfa(
      baslik: widget.oge == null ? 'Programa ekle' : 'Programı düzenle',
      kaydet: _kaydet,
      sil: widget.oge == null
          ? null
          : () => Veri.sil(widget.durum.aid, 'program', widget.oge!.id),
      children: [
        Alan(
          'Ne yapılacak?',
          TextField(
            controller: _baslik,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Örn. Çocuklarla parka gitmek'),
          ),
        ),
        Alan(
          'Tür',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in ProgramOgesi.turler.entries)
                ChoiceChip(
                  avatar: Icon(turIkon(e.key), size: 18, color: turRenk(e.key)),
                  label: Text(e.value),
                  selected: _tur == e.key,
                  onSelected: (_) => setState(() => _tur = e.key),
                ),
            ],
          ),
        ),
        Alan(
          widget.oge == null ? 'Günler (birkaç gün seçebilirsin)' : 'Gün',
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var g = 1; g <= 7; g++)
                FilterChip(
                  label: Text(gunKisa[g - 1]),
                  selected: _gunler.contains(g),
                  onSelected: (v) => setState(() {
                    if (v) {
                      _gunler = [..._gunler, g]..sort();
                    } else {
                      _gunler = _gunler.where((x) => x != g).toList();
                    }
                  }),
                ),
            ],
          ),
        ),
        Alan(
          'Saat ve süre',
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saatSec,
                  icon: const Icon(Icons.schedule),
                  label: Text(saatYaz(_saat)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 2)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _sureler.contains(_sure) ? _sure : 60,
                      items: [
                        for (final s in _sureler)
                          DropdownMenuItem(value: s, child: Text(sureYaz(s))),
                      ],
                      onChanged: (v) => setState(() => _sure = v ?? 60),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Alan(
          'Kimlerle?',
          KisiSecici(
            aile: aile,
            secili: _kisiler,
            degisti: (l) => setState(() => _kisiler = l),
          ),
        ),
      ],
    );
  }
}

// --- Plan / hedef -----------------------------------------------------------

class PlanFormu extends StatefulWidget {
  const PlanFormu({super.key, required this.durum, this.plan, this.vade = 'kisa'});
  final Durum durum;
  final Plan? plan;
  final String vade;

  @override
  State<PlanFormu> createState() => _PlanFormuState();
}

class _PlanFormuState extends State<PlanFormu> {
  late final _baslik = TextEditingController(text: widget.plan?.baslik ?? '');
  late final _aciklama = TextEditingController(text: widget.plan?.aciklama ?? '');
  late final _butce = TextEditingController(
      text: (widget.plan?.butce ?? 0) > 0 ? sayi(widget.plan!.butce) : '');
  late String _vade = widget.plan?.vade ?? widget.vade;
  late int _tarih = widget.plan?.tarih ?? 0;
  late List<String> _kisiler = [...?widget.plan?.kisiler];
  late double _ilerleme = (widget.plan?.ilerleme ?? 0).toDouble();

  @override
  void dispose() {
    _baslik.dispose();
    _aciklama.dispose();
    _butce.dispose();
    super.dispose();
  }

  Future<void> _tarihSec() async {
    final simdi = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _tarih > 0
          ? DateTime.fromMillisecondsSinceEpoch(_tarih)
          : simdi.add(Duration(days: _vade == 'uzun' ? 180 : 3)),
      firstDate: DateTime(simdi.year - 1),
      lastDate: DateTime(simdi.year + 15),
    );
    if (d != null) setState(() => _tarih = DateTime(d.year, d.month, d.day, 12).millisecondsSinceEpoch);
  }

  Future<String?> _kaydet() async {
    final b = _baslik.text.trim();
    if (b.isEmpty) return 'Planın adını yazın.';
    final butce = _butce.text.trim().isEmpty ? 0.0 : sayiOku(_butce.text);
    if (butce == null || butce < 0) return 'Bütçe tutarını rakamla yazın.';
    final veri = <String, dynamic>{
      'baslik': b,
      'aciklama': _aciklama.text.trim(),
      'vade': _vade,
      'tarih': _tarih,
      'kisiler': _kisiler,
      'butce': butce,
      'ilerleme': _ilerleme.round(),
    };
    if (widget.plan == null) {
      veri.addAll({
        'biriken': 0,
        'tamam': false,
        'tamamTarih': 0,
        'harcanan': 0,
        'sure': 0,
        'olusturma': Veri.simdi,
        'olusturan': widget.durum.uid,
      });
    }
    await Veri.kaydet(widget.durum.aid, 'planlar', widget.plan?.id, veri);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final aile = widget.durum.aile!;
    final uzun = _vade == 'uzun';
    return FormSayfa(
      baslik: widget.plan == null ? (uzun ? 'Yeni hedef' : 'Yeni plan') : 'Düzenle',
      kaydet: _kaydet,
      sil: widget.plan == null
          ? null
          : () => Veri.sil(widget.durum.aid, 'planlar', widget.plan!.id),
      children: [
        Alan(
          'Vade',
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'kisa', label: Text('Kısa vadeli'), icon: Icon(Icons.event)),
              ButtonSegment(value: 'uzun', label: Text('Uzun vadeli'), icon: Icon(Icons.flag_outlined)),
            ],
            selected: {_vade},
            onSelectionChanged: (s) => setState(() => _vade = s.first),
          ),
        ),
        Alan(
          uzun ? 'Hedef' : 'Plan',
          TextField(
            controller: _baslik,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
                hintText: uzun ? 'Örn. Yaz tatili, çocuk odası, ehliyet' : 'Örn. Hafta sonu piknik'),
          ),
        ),
        Alan(
          'Not (isteğe bağlı)',
          TextField(
            controller: _aciklama,
            maxLines: 3,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        Alan(
          uzun ? 'Hedef tarih' : 'Ne zaman?',
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _tarihSec,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_tarih == 0
                      ? 'Tarih seç'
                      : tarihYaz(DateTime.fromMillisecondsSinceEpoch(_tarih))),
                ),
              ),
              if (_tarih != 0)
                IconButton(
                    onPressed: () => setState(() => _tarih = 0), icon: const Icon(Icons.close)),
            ],
          ),
        ),
        Alan(
          uzun ? 'Hedef tutar (birikim)' : 'Tahmini bütçe',
          TextField(
            controller: _butce,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(suffixText: '₺', hintText: '0'),
          ),
        ),
        if (uzun)
          Alan(
            'İlerleme: %${_ilerleme.round()} (hedef tutar yoksa bu kullanılır)',
            Slider(
              value: _ilerleme,
              min: 0,
              max: 100,
              divisions: 20,
              label: '%${_ilerleme.round()}',
              onChanged: (v) => setState(() => _ilerleme = v),
            ),
          ),
        Alan(
          'Kimler için?',
          KisiSecici(
            aile: aile,
            secili: _kisiler,
            degisti: (l) => setState(() => _kisiler = l),
          ),
        ),
      ],
    );
  }
}

// --- Harcama ----------------------------------------------------------------

class HarcamaFormu extends StatefulWidget {
  const HarcamaFormu({super.key, required this.durum, this.harcama});
  final Durum durum;
  final Harcama? harcama;

  @override
  State<HarcamaFormu> createState() => _HarcamaFormuState();
}

class _HarcamaFormuState extends State<HarcamaFormu> {
  late final _tutar =
      TextEditingController(text: widget.harcama == null ? '' : sayi(widget.harcama!.tutar));
  late final _aciklama = TextEditingController(text: widget.harcama?.aciklama ?? '');
  late String _kategori = widget.harcama?.kategori ?? 'etkinlik';
  late List<String> _kisiler = [...?widget.harcama?.kisiler];
  late int _tarih = widget.harcama?.tarih ?? Veri.simdi;

  @override
  void dispose() {
    _tutar.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  Future<void> _tarihSec() async {
    final simdi = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.fromMillisecondsSinceEpoch(_tarih),
      firstDate: DateTime(simdi.year - 1),
      lastDate: simdi,
    );
    if (d != null) setState(() => _tarih = DateTime(d.year, d.month, d.day, 12).millisecondsSinceEpoch);
  }

  Future<String?> _kaydet() async {
    final t = sayiOku(_tutar.text);
    if (t == null || t <= 0) return 'Tutarı yazın.';
    final veri = <String, dynamic>{
      'tutar': t,
      'aciklama': _aciklama.text.trim(),
      'kategori': _kategori,
      'kisiler': _kisiler,
      'tarih': _tarih,
    };
    if (widget.harcama == null) {
      veri['olusturan'] = widget.durum.uid;
      veri['planId'] = '';
    }
    await Veri.kaydet(widget.durum.aid, 'harcamalar', widget.harcama?.id, veri);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final aile = widget.durum.aile!;
    return FormSayfa(
      baslik: widget.harcama == null ? 'Harcama ekle' : 'Harcamayı düzenle',
      kaydet: _kaydet,
      sil: widget.harcama == null
          ? null
          : () => Veri.sil(widget.durum.aid, 'harcamalar', widget.harcama!.id),
      children: [
        Alan(
          'Tutar',
          TextField(
            controller: _tutar,
            autofocus: widget.harcama == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(suffixText: '₺', hintText: '0'),
          ),
        ),
        Alan(
          'Ne için?',
          TextField(
            controller: _aciklama,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Örn. Lunapark, sinema'),
          ),
        ),
        Alan(
          'Kategori',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in Harcama.kategoriler.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: _kategori == e.key,
                  onSelected: (_) => setState(() => _kategori = e.key),
                ),
            ],
          ),
        ),
        Alan(
          'Tarih',
          OutlinedButton.icon(
            onPressed: _tarihSec,
            icon: const Icon(Icons.calendar_today),
            label: Text(tarihYaz(DateTime.fromMillisecondsSinceEpoch(_tarih))),
          ),
        ),
        Alan(
          'Kimin için?',
          KisiSecici(
            aile: aile,
            secili: _kisiler,
            degisti: (l) => setState(() => _kisiler = l),
            herkesYazisi: 'Ortak',
          ),
        ),
      ],
    );
  }
}

// --- Dilek ------------------------------------------------------------------

class DilekFormu extends StatefulWidget {
  const DilekFormu({super.key, required this.durum, this.dilek});
  final Durum durum;
  final Dilek? dilek;

  @override
  State<DilekFormu> createState() => _DilekFormuState();
}

class _DilekFormuState extends State<DilekFormu> {
  late final _baslik = TextEditingController(text: widget.dilek?.baslik ?? '');
  late final _maliyet = TextEditingController(
      text: (widget.dilek?.maliyet ?? 0) > 0 ? sayi(widget.dilek!.maliyet) : '');
  late String _kimden = widget.dilek?.kimden ?? widget.durum.kisiId;
  late int _oncelik = widget.dilek?.oncelik ?? 2;

  @override
  void dispose() {
    _baslik.dispose();
    _maliyet.dispose();
    super.dispose();
  }

  Future<String?> _kaydet() async {
    final b = _baslik.text.trim();
    if (b.isEmpty) return 'Dileği yazın.';
    final m = _maliyet.text.trim().isEmpty ? 0.0 : sayiOku(_maliyet.text);
    if (m == null) return 'Tahmini maliyeti rakamla yazın.';
    final veri = <String, dynamic>{
      'baslik': b,
      'kimden': _kimden,
      'maliyet': m,
      'oncelik': _oncelik,
    };
    if (widget.dilek == null) {
      veri.addAll({
        'durum': 'bekliyor',
        'olusturan': widget.durum.uid,
        'olusturma': Veri.simdi,
      });
    }
    await Veri.kaydet(widget.durum.aid, 'dilekler', widget.dilek?.id, veri);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final aile = widget.durum.aile!;
    return FormSayfa(
      baslik: widget.dilek == null ? 'Dilek ekle' : 'Dileği düzenle',
      kaydet: _kaydet,
      sil: widget.dilek == null
          ? null
          : () => Veri.sil(widget.durum.aid, 'dilekler', widget.dilek!.id),
      children: [
        Alan(
          'Kimin dileği?',
          KisiSecici(
            aile: aile,
            tek: true,
            secili: [_kimden],
            degisti: (l) => setState(() => _kimden = l.first),
          ),
        ),
        Alan(
          'Dilek',
          TextField(
            controller: _baslik,
            autofocus: widget.dilek == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                hintText: 'Örn. Hayvanat bahçesine gitmek, bisiklet, baş başa yemek'),
          ),
        ),
        Alan(
          'Ne kadar istiyor?',
          SegmentedButton<int>(
            segments: [
              for (final e in Dilek.oncelikler.entries)
                ButtonSegment(value: e.key, label: Text(e.value, style: const TextStyle(fontSize: 12.5))),
            ],
            selected: {_oncelik},
            onSelectionChanged: (s) => setState(() => _oncelik = s.first),
          ),
        ),
        Alan(
          'Tahmini maliyet (isteğe bağlı)',
          TextField(
            controller: _maliyet,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(suffixText: '₺', hintText: '0'),
          ),
        ),
      ],
    );
  }
}

// --- Alışkanlık -------------------------------------------------------------

class AliskanlikFormu extends StatefulWidget {
  const AliskanlikFormu({super.key, required this.durum, this.aliskanlik});
  final Durum durum;
  final Aliskanlik? aliskanlik;

  @override
  State<AliskanlikFormu> createState() => _AliskanlikFormuState();
}

class _AliskanlikFormuState extends State<AliskanlikFormu> {
  late final _baslik = TextEditingController(text: widget.aliskanlik?.baslik ?? '');
  late List<int> _gunler = [...?widget.aliskanlik?.gunler];
  late List<String> _kisiler = [...?widget.aliskanlik?.kisiler];

  static const _oneriler = [
    'Çocuklarla 20 dakika telefonsuz vakit',
    'Yatmadan önce masal okumak',
    'Eşimle günün nasıl geçtiğini konuşmak',
    '30 dakika yürüyüş',
    'Kitap okumak (10 sayfa)',
    'Ailece akşam yemeği',
  ];

  @override
  void dispose() {
    _baslik.dispose();
    super.dispose();
  }

  Future<String?> _kaydet() async {
    final b = _baslik.text.trim();
    if (b.isEmpty) return 'Alışkanlığı yazın.';
    final veri = <String, dynamic>{'baslik': b, 'gunler': _gunler, 'kisiler': _kisiler};
    if (widget.aliskanlik == null) {
      veri['yapilan'] = <String>[];
      veri['olusturma'] = Veri.simdi;
    }
    await Veri.kaydet(widget.durum.aid, 'aliskanliklar', widget.aliskanlik?.id, veri);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final aile = widget.durum.aile!;
    return FormSayfa(
      baslik: widget.aliskanlik == null ? 'Alışkanlık ekle' : 'Alışkanlığı düzenle',
      kaydet: _kaydet,
      sil: widget.aliskanlik == null
          ? null
          : () => Veri.sil(widget.durum.aid, 'aliskanliklar', widget.aliskanlik!.id),
      children: [
        Alan(
          'Alışkanlık',
          TextField(
            controller: _baslik,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Her gün yapmak istediğin küçük şey'),
          ),
        ),
        if (widget.aliskanlik == null)
          Alan(
            'Öneriler',
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in _oneriler)
                  ActionChip(label: Text(o), onPressed: () => setState(() => _baslik.text = o)),
              ],
            ),
          ),
        Alan('Hangi günler?', GunSecici(secili: _gunler, degisti: (l) => setState(() => _gunler = l))),
        Alan(
          'Kimlerle / kim için?',
          KisiSecici(aile: aile, secili: _kisiler, degisti: (l) => setState(() => _kisiler = l)),
        ),
      ],
    );
  }
}

const List<(String, IconData, String)> _menu = [
  ('program', Icons.calendar_view_week, 'Haftalık programa ekle'),
  ('kisa', Icons.event, 'Kısa vadeli plan'),
  ('uzun', Icons.flag_outlined, 'Uzun vadeli hedef'),
  ('harcama', Icons.payments_outlined, 'Harcama'),
  ('dilek', Icons.card_giftcard, 'Dilek kutusuna ekle'),
  ('aliskanlik', Icons.repeat, 'Alışkanlık'),
];

/// Hızlı ekleme menüsü.
Future<void> hizliEkle(BuildContext context, Durum d) async {
  final secim = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in _menu)
            ListTile(
              leading: Icon(m.$2, color: Renk.ana),
              title: Text(m.$3),
              onTap: () => Navigator.pop(ctx, m.$1),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (secim == null || !context.mounted) return;
  final Widget sayfa = switch (secim) {
    'program' => ProgramFormu(durum: d, gun: DateTime.now().weekday),
    'kisa' => PlanFormu(durum: d, vade: 'kisa'),
    'uzun' => PlanFormu(durum: d, vade: 'uzun'),
    'harcama' => HarcamaFormu(durum: d),
    'dilek' => DilekFormu(durum: d),
    _ => AliskanlikFormu(durum: d),
  };
  await ac(context, sayfa);
}
