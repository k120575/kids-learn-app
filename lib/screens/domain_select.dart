import 'package:flutter/material.dart';

import '../content/registry.dart';
import '../content/themes.dart';
import '../core/audio_service.dart';
import '../core/progress_store.dart';
import '../core/responsive.dart';
import '../core/theme.dart';
import '../core/widgets/game_scaffold.dart';
import '../core/widgets/theme_background.dart';
import '../models/age_band.dart';
import '../models/domain.dart';
import '../models/game_def.dart';
import 'game_list.dart';

/// 主題探索地圖：依年齡段套上沉浸式動畫背景（遊樂園 / 太空），
/// 把領域包裝成「設施 / 星球」站點。玩過的站點亮燈顯示星數，全 3 星亮完成標記。
class DomainSelectScreen extends StatefulWidget {
  const DomainSelectScreen({super.key, required this.band});

  final AgeBand band;

  @override
  State<DomainSelectScreen> createState() => _DomainSelectScreenState();
}

class _DomainSelectScreenState extends State<DomainSelectScreen> {
  WorldTheme? get _world => worldFor(widget.band);

  @override
  void initState() {
    super.initState();
    final WorldTheme? w = _world;
    if (w != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => AudioService.instance.speak(w.greeting),
      );
    }
  }

  @override
  void dispose() {
    // 退出地圖（例如歡迎詞還沒念完就返回首頁）時，停掉正在念的語音。
    AudioService.instance.stop();
    super.dispose();
  }

  /// 站點排成上下平均的兩列（5 關 → 上 3 下 2），避免「上 4 下 1」看了煩。
  /// 關卡 ≤3 時單列即可。每列用 Wrap，窄螢幕仍能優雅換行。
  Widget _stationGrid(BuildContext context, List<Domain> domains) {
    if (domains.length <= 3) return _stationRow(context, domains);
    final int top = (domains.length / 2).ceil();
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _stationRow(context, domains.sublist(0, top)),
        SizedBox(height: context.s(Sizes.bigGap)),
        _stationRow(context, domains.sublist(top)),
      ],
    );
  }

  Widget _stationRow(BuildContext context, List<Domain> domains) {
    return Wrap(
      spacing: context.s(Sizes.bigGap),
      runSpacing: context.s(Sizes.bigGap),
      alignment: WrapAlignment.center,
      children: domains.map((Domain d) {
        final Station st = _world?.stationFor(d) ?? Station(d.label, d.emoji);
        final (int, int) s = _stars(d);
        final bool complete = s.$2 > 0 && s.$1 >= s.$2;
        return _StationCard(
          station: st,
          color: d.color,
          got: s.$1,
          complete: complete,
          onTap: () async {
            AudioService.instance.speak(st.name);
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GameListScreen(
                  band: widget.band,
                  domain: d,
                  stationName: st.name,
                ),
              ),
            );
            if (mounted) setState(() {});
          },
        );
      }).toList(),
    );
  }

  (int got, int total) _stars(Domain d) {
    final List<GameDef> games = gameRegistry
        .where((GameDef g) => g.matches(widget.band, d))
        .toList();
    final int got = games.fold<int>(
      0,
      (int a, GameDef g) => a + ProgressStore.instance.starsFor(g.id),
    );
    return (got, games.length * 3);
  }

  @override
  Widget build(BuildContext context) {
    final WorldTheme? world = _world;
    final bool dark = worldIsDark(widget.band);
    final List<Domain> domains = Domain.values
        .where(
          (Domain d) =>
              gameRegistry.any((GameDef g) => g.matches(widget.band, d)),
        )
        .toList();

    return GameScaffold(
      title: world?.mapTitle ?? '${widget.band.label}・玩什麼？',
      backgroundWidget: worldBackground(widget.band),
      foregroundColor: dark ? Colors.white : const Color(0xFF40454F),
      onReplay: world != null
          ? () => AudioService.instance.speak(world.greeting)
          : null,
      // 內容短時置中、站點多到超過可視高度時可往下捲（不要用 Center 包
      // SingleChildScrollView，否則超高會被裁切又捲不到——同扭蛋機曾犯的錯）。
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) =>
            SingleChildScrollView(
              padding: EdgeInsets.all(context.s(Sizes.gap)),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: c.maxHeight - Sizes.gap * 2,
                ),
                child: Center(child: _stationGrid(context, domains)),
              ),
            ),
      ),
    );
  }
}

/// 地圖上的站點：圓形童書插畫徽章當入口（缺圖退回 emoji 圓牌），
/// 下方白底名稱條，右上角亮燈徽章（星數 / 完成）。
class _StationCard extends StatelessWidget {
  const _StationCard({
    required this.station,
    required this.color,
    required this.got,
    required this.complete,
    required this.onTap,
  });

  final Station station;
  final Color color;
  final int got;
  final bool complete;
  final VoidCallback onTap;

  static const double _d = 176; // 徽章直徑（放大，讓站點 ICON 更顯眼好點）

  @override
  Widget build(BuildContext context) {
    final bool visited = got > 0;
    // 依可用寬度夾住（RWD）：大平板上 context.s 會吃滿 1.6× 上限，讓站點圖示
    // 過大、一排塞不下。取「設計縮放後尺寸」與「螢幕寬 1/6」較小者，
    // 確保一排約可容納 5 個站點而不溢出；手機（短邊小）多半仍取原尺寸。
    final double byScale = context.s(_d);
    final double byWidth = MediaQuery.of(context).size.width / 6;
    final double d = byScale < byWidth ? byScale : byWidth;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Container(
                width: d,
                height: d,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: (visited ? color : Colors.black).withValues(
                        alpha: 0.4,
                      ),
                      blurRadius: visited ? 18 : 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipOval(child: _medallion(context, d)),
              ),
              Positioned(
                top: context.s(-2),
                right: context.s(-2),
                child: _badge(context),
              ),
            ],
          ),
          SizedBox(height: context.s(8)),
          // 名稱條：白底，深淺背景上都清楚
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.s(14),
              vertical: context.s(5),
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              station.name,
              style: TextStyle(
                fontSize: context.s(19),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 插畫徽章（缺圖退回彩色圓牌 + emoji）。
  Widget _medallion(BuildContext context, double d) {
    final Widget fallback = Container(
      color: color.withValues(alpha: 0.9),
      alignment: Alignment.center,
      child: Text(station.emoji, style: TextStyle(fontSize: context.s(86))),
    );
    if (station.image == null) return fallback;
    return Image.asset(
      'assets/images/${station.image}.png',
      width: d,
      height: d,
      fit: BoxFit.cover,
      errorBuilder: (BuildContext c, Object e, StackTrace? s) => fallback,
    );
  }

  Widget _badge(BuildContext context) {
    if (complete) {
      return Container(
        padding: EdgeInsets.all(context.s(4)),
        decoration: const BoxDecoration(
          color: Color(0xFF4CAF50),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.check_rounded,
          size: context.s(18),
          color: Colors.white,
        ),
      );
    }
    if (got > 0) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.s(8),
          vertical: context.s(3),
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFC107), width: 1.5),
        ),
        child: Text(
          '⭐$got',
          style: TextStyle(
            fontSize: context.s(14),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
