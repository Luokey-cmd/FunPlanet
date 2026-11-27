import 'package:flutter/material.dart';

import '../data/product_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../widgets/product_image.dart';
import '../widgets/staggered_product_grid.dart';
import 'xiaodou_chat_page.dart';

/// 系列页（2026-11-27，系列横幅的落点）：首页轮播点系列横幅进来。
/// 结构自上而下：横幅大图（图里已烧系列名）→ 一句话世界 → 角色阵容 →
/// 「让小豆带我逛这个系列」→ 这个系列的全部商品（商城同款卡片网格）。
/// 角色头像可点：跳到角色商品页，只看这一个角色的商品
/// （匹配口径见 _characterProducts 的注释）。
/// 商品按 Product.series 精确匹配取，页内按销量从高到低；
/// 系列介绍与阵容是设计稿定死的文案，写在本文件 _seriesInfo 里，
/// 数据库不存这些（商品表只有系列名一列）。
class SeriesPage extends StatelessWidget {
  const SeriesPage({super.key, required this.seriesName, required this.bannerImagePath});

  final String seriesName;
  final String bannerImagePath;

  @override
  Widget build(BuildContext context) {
    final info = _seriesInfo[seriesName];
    final items = products.where((p) => p.series == seriesName).toList()
      ..sort((a, b) => b.sales.compareTo(a.sales));
    return Scaffold(
      backgroundColor: Colors.white,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: bannerAspectRatio,
                child: ProductImage(image: bannerImagePath, fit: BoxFit.cover),
              ),
              Positioned(
                left: AppScale.s(10),
                top: MediaQuery.of(context).padding.top + AppScale.s(8),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: EdgeInsets.all(AppScale.s(7)),
                    decoration: const BoxDecoration(
                      color: Color(0xB3FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_back, size: AppScale.s(19), color: AppColors.foreground),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(AppScale.s(16), AppScale.s(14), AppScale.s(16), AppScale.s(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (info != null) ...[
                  Text(
                    info.tagline,
                    style: TextStyle(fontSize: AppScale.t(13.5), color: AppColors.mutedForeground, height: 1.5),
                  ),
                  SizedBox(height: AppScale.s(16)),
                  Text(
                    '角色阵容',
                    style: TextStyle(fontSize: AppScale.t(15), fontWeight: FontWeight.w700, color: AppColors.foreground),
                  ),
                  SizedBox(height: AppScale.s(10)),
                  SizedBox(
                    height: AppScale.s(98),
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: info.cast.length,
                      separatorBuilder: (_, _) => SizedBox(width: AppScale.s(14)),
                      itemBuilder: (context, i) {
                        final member = info.cast[i];
                        // 点头像（连同名字整块）跳角色商品页（hx 2026-11-27 点名）：
                        // 只列这一个角色的商品，匹配口径见 _characterProducts。
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _CharacterProductsPage(
                                seriesName: seriesName,
                                member: member,
                                castNames: info.cast.map((m) => m.name).toList(),
                              ),
                            ),
                          ),
                          child: Column(
                            children: [
                              // 头像图是从对应系列横幅里裁的角色脸（hx 2026-11-27
                              // 点名），底色保留作图片加载前的占位。
                              CircleAvatar(
                                radius: AppScale.s(24),
                                backgroundColor: member.color,
                                backgroundImage: AssetImage(member.avatar),
                              ),
                              SizedBox(height: AppScale.s(5)),
                              Text(
                                member.name,
                                style: TextStyle(fontSize: AppScale.t(12.5), fontWeight: FontWeight.w600, color: AppColors.foreground),
                              ),
                              Text(
                                member.role,
                                style: TextStyle(fontSize: AppScale.t(10.5), color: AppColors.mutedForeground),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: AppScale.s(16)),
                ],
                FilledButton.icon(
                  onPressed: () => XiaodouChatPage.open(
                    context,
                    initialPrompt: '带我逛逛《$seriesName》系列，帮我挑几件值得买的',
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 17),
                  label: const Text('让小豆带我逛这个系列'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(vertical: AppScale.s(12)),
                  ),
                ),
                SizedBox(height: AppScale.s(18)),
                Text(
                  '系列商品 · ${items.length} 件',
                  style: TextStyle(fontSize: AppScale.t(15), fontWeight: FontWeight.w700, color: AppColors.foreground),
                ),
                SizedBox(height: AppScale.s(10)),
                StaggeredProductGrid(products: items),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 挑「这一个角色的商品」：输入是系列名、角色名和本系列全部角色名，
/// 输出是该角色的商品列表（按销量从高到低，与系列页同口径）。
/// 匹配规则两层：① 商品名里带角色名 → 就是这个角色的商品；
/// ② 商品名里不带任何角色名、但介绍里提了这个角色 → 是全员/场景类
/// 商品（如三人同框的吧唧、拼图、场景手办），也算「包含这个角色」。
/// 坑：第②层必须先卡「名里没有任何角色名」，否则单人商品介绍里的
/// 串场提及（「和岚音、小满摆一起」）会把别人的商品误收进来。
List<Product> _characterProducts(String seriesName, String memberName, List<String> castNames) {
  final items = products.where((p) => p.series == seriesName);
  final matched = items.where((p) {
    if (p.name.contains(memberName)) return true;
    if (castNames.any((n) => p.name.contains(n))) return false;
    return p.description.contains(memberName);
  }).toList();
  matched.sort((a, b) => b.sales.compareTo(a.sales));
  return matched;
}

/// 角色商品页（2026-11-27，hx 点名）：在系列页点角色头像进来，
/// 只看这一个角色的商品。结构：顶栏（返回 + 头像 + 角色名/系列名/件数）
/// → 商城同款卡片网格；一件都没有时给空态文案，不白屏。
class _CharacterProductsPage extends StatelessWidget {
  const _CharacterProductsPage({required this.seriesName, required this.member, required this.castNames});

  final String seriesName;
  final _CastMember member;
  final List<String> castNames;

  @override
  Widget build(BuildContext context) {
    final items = _characterProducts(seriesName, member.name, castNames);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(AppScale.s(10), AppScale.s(8), AppScale.s(16), AppScale.s(8)),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: EdgeInsets.all(AppScale.s(7)),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F0F5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.arrow_back, size: AppScale.s(19), color: AppColors.foreground),
                    ),
                  ),
                  SizedBox(width: AppScale.s(10)),
                  CircleAvatar(
                    radius: AppScale.s(20),
                    backgroundColor: member.color,
                    backgroundImage: AssetImage(member.avatar),
                  ),
                  SizedBox(width: AppScale.s(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          style: TextStyle(fontSize: AppScale.t(16), fontWeight: FontWeight.w700, color: AppColors.foreground),
                        ),
                        Text(
                          '$seriesName · ${member.role} · 共 ${items.length} 件',
                          style: TextStyle(fontSize: AppScale.t(11.5), color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        '这个角色暂时还没有专属商品',
                        style: TextStyle(fontSize: AppScale.t(13), color: AppColors.mutedForeground),
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(AppScale.s(16), AppScale.s(6), AppScale.s(16), AppScale.s(24)),
                      children: [StaggeredProductGrid(products: items)],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 系列介绍文案：tagline 是一句话世界，cast 是角色阵容
/// （名字、定位、代表色——色只用来给头像圆底上色）。
class _SeriesInfo {
  const _SeriesInfo({required this.tagline, required this.cast});

  final String tagline;
  final List<_CastMember> cast;
}

class _CastMember {
  const _CastMember(this.name, this.role, this.color, this.avatar);

  final String name;
  final String role;
  final Color color;

  /// 头像图路径：从该系列横幅原图裁出的角色脸，assets/images/cast-*.jpg
  final String avatar;
}

const _seriesInfo = <String, _SeriesInfo>{
  '星屿邮局': _SeriesInfo(
    tagline: '漂浮在云海上的小岛邮局，专门投递那些没能寄出的信。',
    cast: [
      _CastMember('岚音', '站长', Color(0xFF7C9CBF), 'assets/images/cast-postoffice-1.jpg'),
      _CastMember('祁舟', '信使', Color(0xFFB07B4F), 'assets/images/cast-postoffice-2.jpg'),
      _CastMember('小满', '见习邮员', Color(0xFFE0B83C), 'assets/images/cast-postoffice-3.jpg'),
      _CastMember('团团', '信鸽伙伴', Color(0xFF9FB2BF), 'assets/images/cast-postoffice-4.jpg'),
    ],
  ),
  '山海小食堂': _SeriesInfo(
    tagline: '山海经神兽们开的一间小食堂，个个都是厨子。',
    cast: [
      _CastMember('阿泽', '白泽 · 大厨', Color(0xFF5FA8A0), 'assets/images/cast-canteen-1.jpg'),
      _CastMember('麟麟', '麒麟 · 点心师', Color(0xFF57B98F), 'assets/images/cast-canteen-2.jpg'),
      _CastMember('阿九', '九尾狐 · 茶艺师', Color(0xFFF0A35E), 'assets/images/cast-canteen-3.jpg'),
    ],
  ),
  '月光马戏团': _SeriesInfo(
    tagline: '只在月圆之夜出现的巡回马戏团，华丽又梦幻。',
    cast: [
      _CastMember('罗莎', '魔术师团长', Color(0xFF9E2B25), 'assets/images/cast-circus-1.jpg'),
      _CastMember('雪莉', '空中飞人', Color(0xFFA8B0BE), 'assets/images/cast-circus-2.jpg'),
      _CastMember('安珀', '小丑兼驯兽师', Color(0xFFE8912D), 'assets/images/cast-circus-3.jpg'),
    ],
  ),
  '霓虹夜行': _SeriesInfo(
    tagline: '深夜城市里的一群夜行者，黑客、DJ 和一台机器人。',
    cast: [
      _CastMember('零七', '黑客', Color(0xFF3E7BFA), 'assets/images/cast-neon-1.jpg'),
      _CastMember('沈昼', 'DJ 情报商', Color(0xFFFF5C8A), 'assets/images/cast-neon-2.jpg'),
      _CastMember('小电', '机器人伙伴', Color(0xFF9DB50C), 'assets/images/cast-neon-3.jpg'),
    ],
  ),
  '深海观测站': _SeriesInfo(
    tagline: '海底观测站里的日常，深海与水母的治愈世界。',
    cast: [
      _CastMember('汐月', '观测员', Color(0xFF2E5F8A), 'assets/images/cast-deepsea-1.jpg'),
      _CastMember('沧', '潜水员', Color(0xFF2F6B4F), 'assets/images/cast-deepsea-2.jpg'),
      _CastMember('月月', '水母伙伴', Color(0xFF8FC1E3), 'assets/images/cast-deepsea-3.jpg'),
    ],
  ),
  '时光钟表店': _SeriesInfo(
    tagline: '老街上的钟表修理店，时间在这里慢慢走。',
    cast: [
      _CastMember('怀瑾', '学徒', Color(0xFFB07B4F), 'assets/images/cast-clockshop-1.jpg'),
      _CastMember('时砚', '钟表匠', Color(0xFF3B3733), 'assets/images/cast-clockshop-2.jpg'),
      _CastMember('咔哒', '猫头鹰伙伴', Color(0xFFC9A86A), 'assets/images/cast-clockshop-3.jpg'),
    ],
  ),
  '樱庭花艺社': _SeriesInfo(
    tagline: '校园花艺社的春日日常，樱花与花香里的少女和少年。',
    cast: [
      _CastMember('花梨', '社长', Color(0xFFF28BB4), 'assets/images/cast-flower-1.jpg'),
      _CastMember('青禾', '社员', Color(0xFF4CAF7D), 'assets/images/cast-flower-2.jpg'),
      _CastMember('蜜蜜', '蜜蜂伙伴', Color(0xFFF2C230), 'assets/images/cast-flower-3.jpg'),
    ],
  ),
  '极光观测队': _SeriesInfo(
    tagline: '极夜冰原上的观测队，一群追极光的人。',
    cast: [
      _CastMember('极星', '观测员', Color(0xFF7FB3E0), 'assets/images/cast-aurora-1.jpg'),
      _CastMember('凛冬', '队员', Color(0xFF5A6B7C), 'assets/images/cast-aurora-2.jpg'),
      _CastMember('霜霜', '北极狐伙伴', Color(0xFF9FB2BF), 'assets/images/cast-aurora-3.jpg'),
    ],
  ),
};
