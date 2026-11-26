import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';

/// 可领券清单卡：跟在小豆气泡下方，每行一组券、右边一个按钮。
/// 规矩（2026-11-26 hx 定）：小豆只列清单、不代领——可领的行给
/// 「领取」按钮，用户点哪张领哪张；领完翻成「已领取」；会员券给
/// 「去开通」；领完/过期的只留一行灰字说明。
class XiaodouCouponCard extends StatelessWidget {
  const XiaodouCouponCard({
    super.key,
    required this.choices,
    required this.onClaim,
    required this.onMember,
  });

  final List<CouponChoice> choices;
  final ValueChanged<CouponChoice> onClaim;
  final VoidCallback onMember;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: AppScale.s(10)),
      padding: EdgeInsets.all(AppScale.s(12)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppScale.s(12)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '能领的券都在这儿，点按钮领取',
            style: TextStyle(
              fontSize: AppScale.t(13),
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          SizedBox(height: AppScale.s(4)),
          for (var i = 0; i < choices.length; i++) ...[
            if (i > 0) Divider(height: AppScale.s(14), color: AppColors.border),
            _row(choices[i]),
          ],
        ],
      ),
    );
  }

  Widget _row(CouponChoice choice) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                choice.title,
                style: TextStyle(
                  fontSize: AppScale.t(13),
                  fontWeight: FontWeight.w600,
                  color: AppColors.foreground,
                ),
              ),
              if (choice.detail.isNotEmpty)
                Text(
                  choice.detail,
                  style: TextStyle(
                    fontSize: AppScale.t(11.5),
                    height: 1.35,
                    color: AppColors.mutedForeground,
                  ),
                ),
              if (choice.failReason != null && choice.failReason!.isNotEmpty)
                Text(
                  choice.failReason!,
                  style: TextStyle(
                    fontSize: AppScale.t(11.5),
                    height: 1.35,
                    color: const Color(0xFFDC2626),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(width: AppScale.s(10)),
        _trailing(choice),
      ],
    );
  }

  Widget _trailing(CouponChoice choice) {
    switch (choice.status) {
      case 'claimable':
        return GestureDetector(
          onTap: () => onClaim(choice),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: AppScale.s(16), vertical: AppScale.s(7)),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppScale.s(999)),
            ),
            child: Text(
              '领取',
              style: TextStyle(
                fontSize: AppScale.t(12.5),
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        );
      case 'claiming':
        return Container(
          padding: EdgeInsets.symmetric(horizontal: AppScale.s(16), vertical: AppScale.s(7)),
          decoration: BoxDecoration(
            color: AppColors.muted,
            borderRadius: BorderRadius.circular(AppScale.s(999)),
          ),
          child: Text(
            '领取中…',
            style: TextStyle(fontSize: AppScale.t(12.5), color: AppColors.mutedForeground),
          ),
        );
      case 'member':
        return GestureDetector(
          onTap: onMember,
          child: Text(
            '去开通',
            style: TextStyle(
              fontSize: AppScale.t(12.5),
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        );
      case 'claimed':
        return Text(
          '已领取',
          style: TextStyle(fontSize: AppScale.t(12.5), color: AppColors.mutedForeground),
        );
      default:
        return Text(
          choice.statusText,
          style: TextStyle(fontSize: AppScale.t(12.5), color: AppColors.mutedForeground),
        );
    }
  }
}
