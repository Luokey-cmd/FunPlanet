import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import 'xiaodou_fate_cards.dart';

/// 亮牌区（导购全流程拍 4）：牌面调档 + 牌板 + 批次翻页，一整块。
///
/// 批次口径（hx 2026-11-22 定案，取代旧「换一批」）：
/// - 每一批原样存在消息里，上一批/下一批只切下标，不重新抽；
/// - 只有翻到最新一批再点下一批，才向服务端要新的一批（不经模型）；
/// - 池子见底如实说「一共 N 件，都看完啦」，不把旧牌换序重端；
/// - 预算/路线在牌面上方切换，切换后按新条件从第一批重新亮。
class XiaodouFateSection extends StatelessWidget {
  const XiaodouFateSection({
    super.key,
    required this.message,
    required this.loadingBatch,
    required this.onPrev,
    required this.onNext,
    required this.onRefilter,
  });

  final ChatMessage message;
  final bool loadingBatch;
  final VoidCallback onPrev;

  /// 点「下一批」：在最新一批时由上层去拉新一批，否则只是切下标。
  final VoidCallback onNext;

  /// 牌面调档：maxPrice 为 null 表示不限预算（0 是内部哨兵，不会传进来）。
  final void Function({int? maxPrice, String? sort}) onRefilter;

  @override
  Widget build(BuildContext context) {
    final batches = message.fateBatches.isNotEmpty ? message.fateBatches : [message.products];
    final index = message.fateIndex.clamp(0, batches.length - 1);
    final atLast = index >= batches.length - 1;
    final canNext = !atLast || message.fateHasMore;
    final shownCount = batches.fold<int>(0, (sum, b) => sum + b.length);
    final exhausted = atLast && !message.fateHasMore && message.fateTotal > 0 && shownCount >= message.fateTotal;

    final budget = (message.drawArgs['maxPrice'] as num?)?.toInt();
    final sort = message.drawArgs['sort'] as String? ?? 'sales';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: AppScale.s(8)),
        _chipRow(
          label: '预算',
          options: const [
            (null, '不限'),
            (50, '¥50内'),
            (100, '¥100内'),
            (200, '¥200内'),
          ],
          selected: budget,
          onPick: (value) => onRefilter(maxPrice: value ?? 0),
        ),
        SizedBox(height: AppScale.s(6)),
        _chipRow(
          label: '路线',
          options: const [
            ('sales', '综合'),
            ('price_asc', '最省钱'),
            ('rating', '口碑好'),
          ],
          selected: sort,
          onPick: (value) => onRefilter(sort: value),
        ),
        XiaodouFateBoard(
          // 换一批就换 key：牌板重建，新一批明牌直接换上（淡入，不翻）
          key: ValueKey('fate-$index-${batches[index].isEmpty ? 'empty' : batches[index].first.id}'),
          products: batches[index],
          traits: message.traits,
        ),
        if (batches.length > 1 || message.fateHasMore || exhausted) ...[
          SizedBox(height: AppScale.s(8)),
          Row(
            children: [
              // 第 1 批不摆「上一批」（hx 口径：从第 2 批起才出现）；
              // 用等宽占位顶住，让「第 X 批」保持居中、下一批保持靠右。
              if (index > 0)
                _pagerButton(
                  label: '上一批',
                  enabled: !loadingBatch,
                  onTap: onPrev,
                )
              else
                SizedBox(width: AppScale.s(72)),
              Expanded(
                child: Text(
                  '第 ${index + 1} 批',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: AppScale.t(11.5), color: AppColors.mutedForeground),
                ),
              ),
              _pagerButton(
                label: '下一批',
                enabled: canNext && !loadingBatch,
                onTap: onNext,
                loading: loadingBatch,
              ),
            ],
          ),
        ],
        if (exhausted)
          Padding(
            padding: EdgeInsets.only(top: AppScale.s(6)),
            child: Text(
              '符合的一共 ${message.fateTotal} 件，都看完啦。换个预算档或路线，还能再挑挑。',
              style: TextStyle(fontSize: AppScale.t(11.5), height: 1.4, color: AppColors.mutedForeground),
            ),
          ),
      ],
    );
  }

  Widget _chipRow<T>({
    required String label,
    required List<(T, String)> options,
    required T selected,
    required ValueChanged<T> onPick,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: AppScale.t(11.5), color: AppColors.mutedForeground),
        ),
        SizedBox(width: AppScale.s(8)),
        Expanded(
          child: Wrap(
            spacing: AppScale.s(6),
            children: [
              for (final option in options)
                GestureDetector(
                  onTap: loadingBatch || option.$1 == selected ? null : () => onPick(option.$1),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: AppScale.s(10), vertical: AppScale.s(4)),
                    decoration: BoxDecoration(
                      color: option.$1 == selected ? AppColors.primary : AppColors.card,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: option.$1 == selected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Text(
                      option.$2,
                      style: TextStyle(
                        fontSize: AppScale.t(11),
                        fontWeight: FontWeight.w600,
                        color: option.$1 == selected ? Colors.white : AppColors.foreground,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pagerButton({
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    bool loading = false,
  }) {
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: EdgeInsets.symmetric(horizontal: AppScale.s(14), vertical: AppScale.s(6)),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: loading
          ? SizedBox(
              width: AppScale.s(14),
              height: AppScale.s(14),
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            )
          : Text(label, style: TextStyle(fontSize: AppScale.t(12), fontWeight: FontWeight.w600)),
    );
  }
}
