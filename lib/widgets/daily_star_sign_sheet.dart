import 'package:flutter/material.dart';

import '../data/product_data.dart';
import '../services/daily_star_sign_storage.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import 'floating_ai_assistant.dart';
import 'product_image.dart';
import 'xiaodou_fate_cards.dart';

/// 打开今日星签半屏层。
///
/// [onDrawTriple] 在层收起之后调用（调用方负责打开小豆并自动抽三翻）。
/// 若用户点遮罩/下滑直接关掉且还没翻牌，这里会把状态补记为 dismissed，
/// 保证当天不再自动弹第二次。
Future<void> showDailyStarSignSheet(
  BuildContext context, {
  required String userId,
  required DailyStarSignRecord record,
  required Product product,
  required VoidCallback onDrawTriple,
}) async {
  final storage = DailyStarSignStorage();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (_) => DailyStarSignSheet(
      userId: userId,
      record: record,
      product: product,
      onDrawTriple: onDrawTriple,
    ),
  );
  final after = await storage.readToday(userId);
  if (after != null && after.state == DailyStarSignState.popped) {
    await storage.save(
      userId,
      after.copyWith(state: DailyStarSignState.dismissed),
    );
  }
}

class DailyStarSignSheet extends StatefulWidget {
  const DailyStarSignSheet({
    super.key,
    required this.userId,
    required this.record,
    required this.product,
    required this.onDrawTriple,
  });

  final String userId;
  final DailyStarSignRecord record;
  final Product product;
  final VoidCallback onDrawTriple;

  @override
  State<DailyStarSignSheet> createState() => _DailyStarSignSheetState();
}

class _DailyStarSignSheetState extends State<DailyStarSignSheet> {
  final _storage = DailyStarSignStorage();
  late bool _flipped;

  @override
  void initState() {
    super.initState();
    _flipped =
        widget.record.state == DailyStarSignState.flipped ||
        widget.record.state == DailyStarSignState.done;
  }

  Future<void> _flip() async {
    if (_flipped) return;
    setState(() => _flipped = true);
    await _storage.save(
      widget.userId,
      widget.record.copyWith(
        state: DailyStarSignState.flipped,
        productId: widget.product.id,
      ),
    );
    await _storage.pushRecent(widget.userId, widget.product.id);
  }

  Future<void> _dismiss() async {
    await _storage.save(
      widget.userId,
      widget.record.copyWith(state: DailyStarSignState.dismissed),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _drawTriple() async {
    await _storage.save(
      widget.userId,
      widget.record.copyWith(
        state: DailyStarSignState.done,
        productId: widget.product.id,
      ),
    );
    if (!mounted) return;
    Navigator.pop(context);
    widget.onDrawTriple();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF251E54), Color(0xFF171238), Color(0xFF110D2A)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppScale.s(20),
        AppScale.s(12),
        AppScale.s(20),
        AppScale.s(24) + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: AppScale.s(36),
            height: AppScale.s(4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          SizedBox(height: AppScale.s(16)),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppScale.s(10)),
                child: ProductImage(
                  image: FloatingAiAssistant.assetFull,
                  width: AppScale.s(36),
                  height: AppScale.s(36),
                ),
              ),
              SizedBox(width: AppScale.s(10)),
              Expanded(
                child: Text(
                  '今日星签',
                  style: TextStyle(
                    fontSize: AppScale.t(17),
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '${now.month}月${now.day}日',
                style: TextStyle(
                  fontSize: AppScale.t(11),
                  color: Colors.white54,
                ),
              ),
            ],
          ),
          SizedBox(height: AppScale.s(10)),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _flipped ? '就是它了。今天的你，和这件宝贝最有缘。' : '今天的星签到了——翻开看看，哪件宝贝在等你。',
              style: TextStyle(
                fontSize: AppScale.t(13),
                color: const Color(0xFFCFC4F5),
                height: 1.4,
              ),
            ),
          ),
          SizedBox(height: AppScale.s(14)),
          Center(
            child: SizedBox(
              width: AppScale.s(190),
              child: XiaodouFateBoard(
                products: [widget.product],
                roles: const ['fate'],
                flipped: _flipped ? const {0} : const <int>{},
                onFlip: (_) => _flip(),
              ),
            ),
          ),
          SizedBox(height: AppScale.s(18)),
          if (!_flipped) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _flip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: const Color(0xFF221638),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppScale.s(14)),
                  ),
                  textStyle: TextStyle(
                    fontSize: AppScale.t(15),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('翻开这张牌'),
              ),
            ),
            TextButton(
              onPressed: _dismiss,
              child: Text(
                '今天先不翻',
                style: TextStyle(
                  fontSize: AppScale.t(13),
                  color: Colors.white60,
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _drawTriple,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: const Color(0xFF221638),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppScale.s(14)),
                  ),
                  textStyle: TextStyle(
                    fontSize: AppScale.t(15),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: const Text('让小豆再翻三张'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '先去逛逛',
                style: TextStyle(
                  fontSize: AppScale.t(13),
                  color: Colors.white60,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
