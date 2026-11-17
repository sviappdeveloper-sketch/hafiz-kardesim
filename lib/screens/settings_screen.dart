import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../services/widget_service.dart';
import 'qibla_screen.dart';
import '../data/cities.dart';
import '../services/notification_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/ornaments.dart';
import '../l10n/l10n.dart';

/// Ayarlar: tema, açılış sesi, ezan vakti için il ve bildirimler.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  bool? _notifOn, _exact, _battery;
  final _preview = AudioPlayer();
  String? _playing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
    _preview.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && mounted) setState(() => _playing = null);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ayarlardan (izin, pil) dönünce durumu yenile.
    if (state == AppLifecycleState.resumed) {
      _checkPermissions().then((_) => NotificationService.rescheduleEzan());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _preview.dispose();
    super.dispose();
  }

  /// Seçilen ezan sesini dinletir; aynı sese yeniden basınca durdurur.
  Future<void> _togglePreview(String id) async {
    if (_playing == id) {
      await _preview.stop();
      setState(() => _playing = null);
      return;
    }
    setState(() => _playing = id);
    try {
      await _preview.setAsset('assets/audio/${id == 'can' ? 'ezan_bildirim' : 'ezan_$id'}.m4a');
      await _preview.seek(Duration.zero);
      await _preview.play();
    } catch (_) {
      if (mounted) setState(() => _playing = null);
    }
  }

  Future<void> _checkPermissions() async {
    final on = await NotificationService.enabled();
    final exact = await NotificationService.canExact();
    final battery = await NotificationService.batteryUnrestricted();
    if (mounted) {
      setState(() {
        _notifOn = on;
        _exact = exact;
        _battery = battery;
      });
    }
  }

  Future<void> _ensurePermission() async {
    if (_notifOn == true) return;
    final ok = await NotificationService.requestPermission();
    if (!ok && mounted) {
      showSnack(context, lt('Bildirim izni verilmedi. Telefon ayarlarından Hafız Kardeşim için bildirimlere izin verebilirsiniz.'));
    }
    await _checkPermissions();
  }

  Future<void> _pickCity() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.ink,
      builder: (_) => const _CityPicker(),
    );
    if (picked == null) return;
    await SettingsService.setCity(picked);
    setState(() {});
    NotificationService.rescheduleEzan();
  }

  @override
  Widget build(BuildContext context) {
    final city = SettingsService.city.value;
    return Scaffold(
      appBar: AppBar(title: Text(lt('Ayarlar'))),
      body: PatternBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            SectionTitle(lt('Dil')),
            const SizedBox(height: 10),
            Row(children: [
              for (final c in Lang.all) ...[
                Expanded(
                  child: _LangChip(
                    code: c,
                    selected: Lang.code == c,
                    onTap: () => SettingsService.setLang(c),
                  ),
                ),
                if (c != Lang.all.last) const SizedBox(width: 10),
              ],
            ]),
            const SizedBox(height: 28),
            SectionTitle(lt('Tema')),
            const SizedBox(height: 12),
            Row(children: [
              for (final p in AppPalette.all) ...[
                Expanded(child: _ThemeCard(palette: p)),
                if (p != AppPalette.all.last) const SizedBox(width: 12),
              ],
            ]),
            const SizedBox(height: 28),
            SectionTitle(lt('Yazı boyutu')),
            const SizedBox(height: 8),
            OrnateCard(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: ValueListenableBuilder<double>(
                valueListenable: SettingsService.textScale,
                builder: (context, v, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Text('A', style: AppText.body(13, weight: FontWeight.w700)),
                    Expanded(
                      child: Slider(
                        value: v,
                        min: 0.85,
                        max: 1.4,
                        divisions: 11,
                        activeColor: AppColors.gold,
                        label: '%${(v * 100).round()}',
                        onChanged: SettingsService.setTextScale,
                      ),
                    ),
                    Text('A', style: AppText.body(22, weight: FontWeight.w700)),
                  ]),
                  Text(lt('Örnek: Bilesiniz ki kalpler ancak Allah\'ı anmakla huzur bulur. (%{0})', [(v * 100).round()]),
                      style: AppText.body(14)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: () => SettingsService.setTextScale(1.0), child: Text(lt('Varsayılan'))),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 28),
            SectionTitle(lt('Ezan vakitleri')),
            const SizedBox(height: 8),
            OrnateCard(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: ListTile(
                leading: Icon(Icons.location_city_outlined, color: AppColors.gold),
                title: Text(lt('İl'), style: AppText.body(15, weight: FontWeight.w600)),
                subtitle: Text(city ?? lt('Seçilmedi — ana sayfada ezan vakitleri için il seçin'),
                    style: AppText.body(13, color: AppColors.muted)),
                trailing: Icon(Icons.chevron_right, color: AppColors.muted),
                onTap: _pickCity,
              ),
            ),
            const SizedBox(height: 12),
            OrnateCard(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(children: [
                // Ana ekran widget'ı ve kalıcı bildirim yalnızca Android'de.
                if (WidgetService.supported) ...[
                _Switch(
                  icon: Icons.widgets_outlined,
                  title: lt('Ana ekran widget\'ı'),
                  subtitle: lt('Telefonunuzun ana ekranında bugünün namaz vakitlerini ve sıradaki vakti göster.'),
                  value: WidgetService.enabled,
                  onChanged: (v) async {
                    await WidgetService.setEnabled(v);
                    setState(() {});
                  },
                ),
                if (WidgetService.enabled) ...[
                  Divider(height: 1, color: AppColors.inkLine),
                  ListTile(
                    leading: Icon(Icons.add_to_home_screen_outlined, color: AppColors.gold),
                    title: Text(lt('Widget\'ı ana ekrana ekle'), style: AppText.body(15, weight: FontWeight.w600)),
                    subtitle: Text(lt('Ana ekranda boş bir yere basılı tutup Widget\'lar bölümünden de ekleyebilirsiniz.'),
                        style: AppText.body(13, color: AppColors.muted)),
                    onTap: () async {
                      final ok = await WidgetService.pin();
                      if (!context.mounted) return;
                      if (!ok) {
                        showSnack(context,
                            lt('Telefonunuz bu kısayolu desteklemiyor. Ana ekranda boş bir yere basılı tutun, Widget\'lar > Hafız Kardeşim\'i seçin.'));
                      }
                    },
                  ),
                ],
                Divider(height: 1, color: AppColors.inkLine),
                _Switch(
                  icon: Icons.notifications_active_outlined,
                  title: lt('Bildirim çubuğunda vakitler'),
                  subtitle: lt('Bildirim çubuğunda sıradaki vakti, ona kalan süreyi ve günün vakitlerini sürekli göster.'),
                  value: WidgetService.barEnabled,
                  onChanged: (v) async {
                    if (v && !await NotificationService.requestPermission()) {
                      if (!context.mounted) return;
                      showSnack(context, lt('Bunun için bildirim izni gerekiyor. Telefon ayarlarından Hafız Kardeşim\'e bildirim izni verin.'));
                      return;
                    }
                    await WidgetService.setBarEnabled(v);
                    if (v && SettingsService.city.value == null && context.mounted) {
                      showSnack(context, lt('Vakitlerin görünmesi için önce il seçin.'));
                    }
                    setState(() {});
                  },
                ),
                Divider(height: 1, color: AppColors.inkLine),
                ],
                ListTile(
                  leading: Icon(Icons.explore_outlined, color: AppColors.gold),
                  title: Text(lt('Kıble pusulası'), style: AppText.body(15, weight: FontWeight.w600)),
                  trailing: Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QiblaScreen())),
                ),
              ]),
            ),
            const SizedBox(height: 28),
            SectionTitle(lt('Bildirimler')),
            const SizedBox(height: 8),
            if (_notifOn == false) ...[
              OrnateCard(
                highlight: true,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(lt('Bildirim izni kapalı'), style: AppText.body(15, weight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(lt('Hatırlatmaları alabilmeniz için bildirim iznine ihtiyaç var.'),
                      style: AppText.body(13, color: AppColors.muted)),
                  const SizedBox(height: 12),
                  GoldButton(label: lt('İzin ver'), icon: Icons.notifications_active_outlined, onPressed: _ensurePermission),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            OrnateCard(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(children: [
                _Switch(
                  icon: Icons.menu_book_outlined,
                  title: lt('Cüz hatırlatması'),
                  subtitle: lt('Aldığınız cüzün teslimine 1 gün kala ve teslim günü haber ver.'),
                  value: SettingsService.notifyJuz,
                  onChanged: (v) async {
                    if (v) await _ensurePermission();
                    await SettingsService.setNotifyJuz(v);
                    setState(() {});
                    showSnack(context, lt('Kaydedildi. Uygulamayı bir sonraki açışınızda hatırlatmalar güncellenir.'));
                  },
                ),
                Divider(height: 1, color: AppColors.inkLine),
                _Switch(
                  icon: Icons.mosque_outlined,
                  title: lt('Ezan vakti bildirimi'),
                  subtitle: city == null ? lt('Önce il seçin.') : lt('{0} için ezan vakitlerinde haber ver.', [city]),
                  value: SettingsService.notifyEzan,
                  onChanged: (v) async {
                    if (v && city == null) {
                      await _pickCity();
                      if (SettingsService.city.value == null) return;
                    }
                    if (v) await _ensurePermission();
                    await SettingsService.setNotifyEzan(v);
                    setState(() {});
                    await NotificationService.rescheduleEzan();
                  },
                ),
                if (SettingsService.notifyEzan)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(lt('Ne zaman haber verilsin?'), style: AppText.body(13, color: AppColors.muted)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final (m, label) in [(0, lt('Vaktinde')), (1, lt('15 dk önce')), (2, lt('İkisi de'))])
                          ChoiceChip(
                            label: Text(label,
                                style: AppText.body(13,
                                    weight: FontWeight.w700,
                                    color: SettingsService.ezanMode == m
                                        ? (AppColors.isLight ? const Color(0xFFFFF8E8) : AppColors.inkDeep)
                                        : AppColors.ivory)),
                            selected: SettingsService.ezanMode == m,
                            onSelected: (_) async {
                              await SettingsService.setEzanMode(m);
                              setState(() {});
                              await NotificationService.rescheduleEzan();
                            },
                          ),
                      ]),
                      const SizedBox(height: 16),
                      Text(lt('Bildirim sesi'), style: AppText.body(13, color: AppColors.muted)),
                      const SizedBox(height: 4),
                      for (final (id, label) in NotificationService.ezanSounds)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Icon(
                              SettingsService.ezanSound == id ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              color: AppColors.gold),
                          title: Text(label, style: AppText.body(14, weight: FontWeight.w600)),
                          trailing: IconButton(
                            tooltip: _playing == id ? lt('Durdur') : lt('Dinle'),
                            icon: Icon(_playing == id ? Icons.stop_circle_outlined : Icons.play_circle_outline,
                                color: AppColors.goldLight),
                            onPressed: () => _togglePreview(id),
                          ),
                          onTap: () async {
                            await SettingsService.setEzanSound(id);
                            setState(() {});
                            await NotificationService.rescheduleEzan();
                          },
                        ),
                      Text(lt('Vakit girdiğinde seçtiğiniz ezan okuyuşunun ilk tekbirleri çalar; 15 dakika kala hatırlatması kısa çan sesiyle gelir. Telefon sessizdeyse ses çalmaz.'),
                          style: AppText.body(12, color: AppColors.muted)),
                      const SizedBox(height: 12),
                      Row(children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            await _ensurePermission();
                            final err = await NotificationService.testEzan();
                            if (!mounted) return;
                            showSnack(
                                context,
                                err == null
                                    ? lt('Deneme bildirimi 10 saniye sonra gelecek. Telefonu kilitleyebilirsiniz.')
                                    : lt('Bildirim planlanamadı: {0}', [err]));
                          },
                          icon: Icon(Icons.notifications_active_outlined, color: AppColors.goldLight, size: 18),
                          label: Text(lt('Sesi bildirimde dene'),
                              style: AppText.body(13, weight: FontWeight.w700, color: AppColors.ivory)),
                          style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)), shape: const StadiumBorder()),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FutureBuilder<int>(
                            future: NotificationService.pendingEzanCount(),
                            builder: (_, snap) => Text(
                              NotificationService.lastEzanError != null
                                  ? lt('Planlama hatası: {0}', [NotificationService.lastEzanError!])
                                  : lt('{0} ezan bildirimi planlandı', ['${snap.data ?? '…'}']),
                              style: AppText.body(11.5, color: AppColors.muted),
                            ),
                          ),
                        ),
                      ]),
                    ]),
                  ),
                Divider(height: 1, color: AppColors.inkLine),
                _Switch(
                  icon: Icons.mail_outline,
                  title: lt('Davet ve mesajlar'),
                  subtitle: lt('Arkadaşlık isteği, grup daveti ve destek yanıtı geldiğinde haber ver.'),
                  value: SettingsService.notifySocial,
                  onChanged: (v) async {
                    if (v) await _ensurePermission();
                    await SettingsService.setNotifySocial(v);
                    setState(() {});
                  },
                ),
              ]),
            ),
            if (SettingsService.notifyEzan && _exact == false) ...[
              const SizedBox(height: 12),
              OrnateCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(lt('Ezan bildirimi tam dakikasında gelsin'),
                      style: AppText.body(14, weight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                      lt('Bu izin kapalıyken telefon, özellikle ekran kapalıyken bildirimi geciktirir ya da hiç çalmaz. "Alarm ve hatırlatıcılar" iznini açarsanız ezan, alarm gibi tam vaktinde okunur.'),
                      style: AppText.body(13, color: AppColors.muted)),
                  const SizedBox(height: 12),
                  GoldButton(
                    label: lt('İzni aç'),
                    outlined: true,
                    onPressed: () async {
                      await NotificationService.requestExact();
                      await _checkPermissions();
                      await NotificationService.rescheduleEzan();
                    },
                  ),
                ]),
              ),
            ],
            if (SettingsService.notifyEzan && _battery == false) ...[
              const SizedBox(height: 12),
              OrnateCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(lt('Ekran kapalıyken de ezan okunsun'), style: AppText.body(14, weight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                      lt('Telefonunuz pil tasarrufu için ekran kapalıyken uygulamaların bildirimlerini erteliyor. Açılan listede Hafız Kardeşim\'i bulup "Kısıtlama yok" ya da "Optimize etme" seçin. Bazı telefonlarda (Xiaomi, Oppo, Realme, Huawei) uygulama ayarlarında "Otomatik başlatma" ve "Arka planda çalışma" izinlerini de açın.'),
                      style: AppText.body(13, color: AppColors.muted)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    GoldButton(
                      label: lt('Pil ayarını aç'),
                      outlined: true,
                      onPressed: NotificationService.openBatterySettings,
                    ),
                    GoldButton(
                      label: lt('Uygulama ayarları'),
                      outlined: true,
                      onPressed: NotificationService.openAppSettings,
                    ),
                  ]),
                ]),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              lt('Bildirimler telefonunuzda planlanır. Uygulama uzun süre açılmazsa ezan bildirimleri en fazla 5 gün ileriye kadar gelir; uygulamayı açtığınızda yeniden planlanır.'),
              style: AppText.body(12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged});
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        value: value,
        onChanged: onChanged,
        secondary: Icon(icon, color: AppColors.gold),
        activeThumbColor: AppColors.inkDeep,
        activeTrackColor: AppColors.gold,
        title: Text(title, style: AppText.body(15, weight: FontWeight.w600)),
        subtitle: Text(subtitle, style: AppText.body(12.5, color: AppColors.muted)),
      );
}

/// Tema seçimi: küçük bir önizleme kartı.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.palette});
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final selected = AppColors.palette.id == p.id;
    return GestureDetector(
      onTap: selected ? null : () => SettingsService.setTheme(p.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.ink,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? p.gold : p.inkLine, width: selected ? 2.2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            height: 54,
            decoration: BoxDecoration(
              color: p.inkSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.gold.withValues(alpha: 0.5)),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 46, height: 6, decoration: BoxDecoration(color: p.gold, borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 8),
              Container(width: 80, height: 5, decoration: BoxDecoration(color: p.ivory.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 5),
              Container(width: 60, height: 5, decoration: BoxDecoration(color: p.muted, borderRadius: BorderRadius.circular(3))),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Text(lt(p.name), style: AppText.body(15, color: p.ivory, weight: FontWeight.w700))),
            if (selected) Icon(Icons.check_circle, size: 20, color: p.gold),
          ]),
          Text(p.light ? lt('Açık · ham parşömen') : lt('Koyu · zümrüt yeşili'),
              style: AppText.body(11.5, color: p.muted)),
        ]),
      ),
    );
  }
}

class _CityPicker extends StatefulWidget {
  const _CityPicker();
  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final list = turkishCities.keys.where((c) => c.toLowerCase().contains(q)).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8 + MediaQuery.viewInsetsOf(context).bottom * 0),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(labelText: lt('İl ara'), prefixIcon: Icon(Icons.search)),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(list[i], style: AppText.body(15)),
                trailing: SettingsService.city.value == list[i] ? Icon(Icons.check, color: AppColors.gold) : null,
                onTap: () => Navigator.pop(context, list[i]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// İl seçme penceresini açar (ana sayfadaki ezan kartından da kullanılır).
Future<void> pickCity(BuildContext context) async {
  final picked = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.ink,
    builder: (_) => const _CityPicker(),
  );
  if (picked == null) return;
  await SettingsService.setCity(picked);
  NotificationService.rescheduleEzan();
}


class _LangChip extends StatelessWidget {
  const _LangChip({required this.code, required this.selected, required this.onTap});
  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: selected ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.gold.withValues(alpha: 0.16) : AppColors.inkSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.gold : AppColors.inkLine, width: selected ? 1.8 : 1),
          ),
          child: Column(children: [
            Text(Lang.names[code]!,
                style: (code == 'ar' ? AppText.arabic(17, color: AppColors.ivory) : AppText.body(15, weight: FontWeight.w700))
                    .copyWith(height: 1.3)),
            if (selected) Icon(Icons.check_circle, size: 16, color: AppColors.gold),
          ]),
        ),
      );
}
