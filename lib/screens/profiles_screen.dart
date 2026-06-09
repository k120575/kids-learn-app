import 'package:flutter/material.dart';

import '../core/progress_store.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets/game_scaffold.dart';
import '../models/profile.dart';

const List<String> kProfileEmojis = <String>[
  '🐧', '🦊', '🐰', '🐻', '🐱', '🐶', '🦁', '🐯', '🐸', '🐼', '🦄', '🐵',
];

/// 孩子檔案管理（由家長鎖進入）：新增、切換、改名、刪除。
/// 每個孩子的星星、貼紙、學習報告各自獨立。
class ProfilesScreen extends StatefulWidget {
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  final ProgressStore _store = ProgressStore.instance;

  Future<void> _edit({Profile? profile}) async {
    final TextEditingController name =
        TextEditingController(text: profile?.name ?? '');
    String emoji = profile?.emoji ?? kProfileEmojis.first;

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setLocal) {
            return AlertDialog(
              title: Text(profile == null ? '新增孩子' : '編輯'),
              // 包 SingleChildScrollView：鍵盤彈出時可用高度變小，emoji 較多時
              // AlertDialog content 預設不捲、底部 emoji 會被切。
              content: SingleChildScrollView(
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: name,
                    autofocus: true,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: '名字',
                      hintText: '例如：小寶',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kProfileEmojis.map((String e) {
                      final bool sel = e == emoji;
                      return GestureDetector(
                        onTap: () => setLocal(() => emoji = e),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: sel
                                ? const Color(0xFFFFF3CD)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: sel
                                  ? const Color(0xFFFFC107)
                                  : Colors.grey.shade300,
                              width: sel ? 3 : 1,
                            ),
                          ),
                          child: Text(e, style: TextStyle(fontSize: context.s(30))),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              )),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('儲存'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok ?? false) {
      final String n = name.text.trim().isEmpty ? '寶貝' : name.text.trim();
      if (profile == null) {
        await _store.addProfile(n, emoji);
      } else {
        await _store.renameProfile(profile.id, n, emoji);
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _delete(Profile p) async {
    if (_store.profiles.length <= 1) return;
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('刪除 ${p.name}？'),
        content: const Text('這個孩子的星星、貼紙、學習報告都會被刪除，無法復原。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (yes ?? false) {
      await _store.deleteProfile(p.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Profile> profiles = _store.profiles;
    return GameScaffold(
      title: '孩子檔案',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(Sizes.bigGap),
            children: <Widget>[
              ...profiles.map((Profile p) {
                final bool active = p.id == _store.activeProfileId;
                return Card(
                  color: active ? const Color(0xFFE3F2FD) : null,
                  child: ListTile(
                    leading: Text(p.emoji, style: TextStyle(fontSize: context.s(34))),
                    title: Text(p.name, style: TextStyle(fontSize: context.s(20))),
                    subtitle: active ? const Text('使用中') : null,
                    onTap: () async {
                      await _store.switchProfile(p.id);
                      if (mounted) setState(() {});
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        IconButton(
                          icon: const Icon(Icons.edit_rounded),
                          onPressed: () => _edit(profile: p),
                        ),
                        if (profiles.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.red),
                            onPressed: () => _delete(p),
                          ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: Sizes.gap),
              ElevatedButton.icon(
                onPressed: () => _edit(),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  textStyle: TextStyle(fontSize: context.s(18)),
                ),
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('新增孩子'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
