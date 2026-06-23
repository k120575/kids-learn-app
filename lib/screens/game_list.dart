import 'package:flutter/material.dart';

import '../content/registry.dart';
import '../core/audio_service.dart';
import '../core/progress_store.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets/big_card.dart';
import '../core/widgets/game_scaffold.dart';
import '../core/widgets/theme_background.dart';
import '../models/age_band.dart';
import '../models/domain.dart';
import '../models/game_def.dart';

/// 某（年齡段 × 領域）下的遊戲清單。資料來自 [gameRegistry]。
class GameListScreen extends StatefulWidget {
  const GameListScreen({
    super.key,
    required this.band,
    required this.domain,
    this.stationName,
  });

  final AgeBand band;
  final Domain domain;

  /// 主題站點名稱（例如「故事屋」「文字星」）。null 則用領域名。
  final String? stationName;

  @override
  State<GameListScreen> createState() => _GameListScreenState();
}

class _GameListScreenState extends State<GameListScreen> {
  @override
  Widget build(BuildContext context) {
    final List<GameDef> games = gameRegistry
        .where((GameDef g) => g.matches(widget.band, widget.domain))
        .toList();

    final bool dark = worldIsDark(widget.band);
    return GameScaffold(
      title: widget.stationName ?? widget.domain.label,
      backgroundWidget: worldBackground(widget.band),
      foregroundColor: dark ? Colors.white : const Color(0xFF40454F),
      child: games.isEmpty
          ? Center(
              child: Text('還沒有遊戲喔', style: TextStyle(fontSize: context.s(22))),
            )
          : LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                // 依可用寬度夾住卡片（RWD）：大平板上 context.s 會吃滿 1.6×，
                // 取「設計縮放後尺寸」與「螢幕寬 1/6」較小者，一排約容 5 張不溢出。
                final double byScale = context.s(170);
                final double byWidth = MediaQuery.of(context).size.width / 6;
                final double cardSize = byScale < byWidth ? byScale : byWidth;
                // 內容短時置中、關卡多到超過可視高度時可往下捲（不用 Center 包
                // SingleChildScrollView，否則超高會被裁切又捲不到）。
                return SingleChildScrollView(
                  padding: EdgeInsets.all(context.s(Sizes.gap)),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: c.maxHeight - Sizes.gap * 2,
                    ),
                    child: Center(
                      child: _gameGrid(context, games, cardSize),
                    ),
                  ),
                );
              },
            ),
    );
  }

  /// 卡片排成上下平均的兩列（6 關→上3下3、5 關→上3下2），避免「上多下一」
  /// 看了不舒服。關卡 ≤3 時單列即可。每列用 Wrap，窄螢幕仍能優雅換行。
  Widget _gameGrid(BuildContext context, List<GameDef> games, double cardSize) {
    if (games.length <= 3) return _gameRow(context, games, cardSize);
    final int top = (games.length / 2).ceil();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _gameRow(context, games.sublist(0, top), cardSize),
        SizedBox(height: context.s(Sizes.bigGap)),
        _gameRow(context, games.sublist(top), cardSize),
      ],
    );
  }

  Widget _gameRow(BuildContext context, List<GameDef> games, double cardSize) {
    return Wrap(
      spacing: context.s(Sizes.bigGap),
      runSpacing: context.s(Sizes.bigGap),
      alignment: WrapAlignment.center,
      children: games.map((GameDef g) {
        final int stars = ProgressStore.instance.starsFor(g.id);
        return BigCard(
          emoji: g.emoji,
          label: g.title,
          color: widget.domain.color,
          size: cardSize,
          solid: true,
          badge: stars > 0 ? StarsRow(count: stars) : null,
          onTap: () async {
            AudioService.instance.speak(g.title);
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: g.builder),
            );
            if (mounted) setState(() {}); // 回來刷新星星
          },
        );
      }).toList(),
    );
  }
}
