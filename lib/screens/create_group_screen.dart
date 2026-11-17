import 'package:flutter/material.dart';

import '../models/constants.dart';
import '../models/models.dart';
import '../services/hatim_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/invite_sheet.dart';
import '../widgets/ornaments.dart';
import 'group_detail_screen.dart';
import '../l10n/l10n.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key, required this.me});
  final AppUser me;
  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  int _days = 7;
  String _type = GenderType.mixed;
  final Set<Friend> _invited = {};
  bool _busy = false;
  String? _blocked;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    HatimService.whyCannotCreate(widget.me).then((why) {
      if (mounted) setState(() {
        _blocked = why;
        _checking = false;
      });
    }).catchError((Object e) {
      if (mounted) setState(() => _checking = false);
    });
  }

  Future<void> _pickFriends() async {
    final picked = await showInviteSheet(context, me: widget.me, initial: _invited);
    if (picked != null) {
      setState(() {
        _invited
          ..clear()
          ..addAll(picked);
      });
    }
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final g = await HatimService.createGroup(
        me: widget.me,
        name: _name.text,
        description: _desc.text,
        durationDays: _days,
        genderType: _type,
      );
      await SocialService.sendGroupInvites(widget.me, g, _invited);
      if (!mounted) return;
      showSnack(context, _invited.isEmpty ? lt('Grup kuruldu. Grup kodu: {0}', [g.code]) : lt('Grup kuruldu, {0} kardeşinize davet gitti.', [_invited.length]));
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: g.id, me: widget.me)));
    } catch (e) {
      if (mounted) {
        showSnack(context, errorText(e));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = [GenderType.mixed, widget.me.gender];
    return Scaffold(
      appBar: AppBar(title: Text(lt('Hatim Grubu Kur'))),
      body: PatternBackground(
        child: _checking
            ? const LoadingView()
            : _blocked != null
                ? SingleChildScrollView(
                    child: EmptyState(
                      title: lt('Henüz grup kuramazsınız'),
                      message: lt('{0}\n\nAçık gruplardan cüz alıp okuyarak bu şartı tamamlayabilirsiniz.', [_blocked]),
                      action: GoldButton(
                        label: lt('Açık gruplara git'),
                        icon: Icons.menu_book_rounded,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  )
                : ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            TextField(
              key: const Key('group_name'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 50,
              decoration: InputDecoration(labelText: lt('Grup adı'), hintText: lt('Örn. Cuma Hatmi')),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const Key('group_desc'),
              controller: _desc,
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: lt('Niyet / açıklama (isteğe bağlı)'),
                hintText: lt('Örn. Rahmetli annemizin ruhu için'),
              ),
            ),
            const SizedBox(height: 18),
            SectionTitle(lt('Hatim süresi')),
            const SizedBox(height: 10),
            OrnateCard(
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$_days', style: AppText.number(44, color: AppColors.goldLight)),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(lt('gün'), style: AppText.display(22, color: AppColors.muted)),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(lt('Hatim bitiş tarihi: {0}', [formatDate(DateTime.now().add(Duration(days: _days)))]),
                            style: AppText.body(12, color: AppColors.muted)),
                      ),
                    ],
                  ),
                  Slider(
                    value: _days.toDouble(),
                    min: minDurationDays.toDouble(),
                    max: maxDurationDays.toDouble(),
                    divisions: maxDurationDays - minDurationDays,
                    label: lt('{0} gün', [_days]),
                    onChanged: (v) => setState(() => _days = v.round()),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [3, 7, 15, 30]
                        .map((d) => ChoiceChip(
                              label: Text(lt('{0} gün', [d]),
                                  style: AppText.body(13,
                                      weight: FontWeight.w700,
                                      color: _days == d
                                          ? (AppColors.isLight ? const Color(0xFFFFF8E8) : AppColors.inkDeep)
                                          : AppColors.ivory)),
                              selected: _days == d,
                              onSelected: (_) => setState(() => _days = d),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(lt('En az {0} gün seçilebilir. Süre grubun kurulduğu andan başlar; bütün cüzlerin teslim tarihi hatmin bitiş tarihidir.', [minDurationDays]),
                      style: AppText.body(11, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SectionTitle(lt('Kimler katılabilir?')),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                for (final t in types) ButtonSegment(value: t, label: FittedBox(fit: BoxFit.scaleDown, child: Text(GenderType.label(t), maxLines: 1, softWrap: false))),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 22),
            SectionTitle(lt('Arkadaşlarınız')),
            const SizedBox(height: 10),
            GoldButton(
              label: _invited.isEmpty ? lt('Arkadaşlarınızı davet edin') : lt('{0} kişi seçildi · düzenle', [_invited.length]),
              icon: Icons.group_add_outlined,
              outlined: true,
              onPressed: _pickFriends,
            ),
            if (_invited.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final f in _invited)
                    InputChip(label: Text(f.name), onDeleted: () => setState(() => _invited.remove(f))),
                ],
              ),
            ],
            const SizedBox(height: 22),
            OrnateCard(
              child: Text(
                lt('Kurallar: Bir kişi bir grupta en fazla {0} cüz alabilir ve cüzünü alır almaz okumaya başlayabilir. Süresi dolup okunmayan cüzler başkaları tarafından yeniden alınabilir. 30 cüzün tamamı okununca hatim kendiliğinden tamamlanır.', [maxJuzPerPerson]),
                style: AppText.body(13, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 22),
            GoldButton(label: lt('Grubu kur'), icon: Icons.check, busy: _busy, onPressed: _create),
          ],
        ),
      ),
    );
  }
}
