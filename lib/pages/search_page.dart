import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/product_data.dart';
import '../providers/cart_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/product_thumbnail.dart';
import '../widgets/sparkle_background.dart';
import 'product_detail_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, this.initialQuery, this.hint});

  final String? initialQuery;
  final String? hint;

  static Future<void> open(BuildContext context, {String? initialQuery, String? hint}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchPage(initialQuery: initialQuery, hint: hint),
      ),
    );
  }

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();
  late String _query;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery ?? '';
    _controller = TextEditingController(text: _query);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<Product> get _results => searchProducts(_query);

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final hint = widget.hint ?? '搜索商品 / 角色 / 周边';

    return Scaffold(
      body: SparkleBackground(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(AppScale.s(8), top + AppScale.s(8), AppScale.s(16), AppScale.s(12)),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, size: AppScale.s(22)),
                  ),
                  Expanded(
                    child: Container(
                      height: AppScale.s(40),
                      padding: EdgeInsets.symmetric(horizontal: AppScale.s(12)),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(AppScale.s(999)),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search, size: AppScale.s(18), color: AppColors.mutedForeground),
                          SizedBox(width: AppScale.s(8)),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              style: TextStyle(fontSize: AppScale.s(14)),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                hintText: hint,
                                hintStyle: TextStyle(fontSize: AppScale.s(14), color: AppColors.mutedForeground),
                              ),
                              onChanged: (v) => setState(() => _query = v),
                              onSubmitted: (v) => setState(() => _query = v),
                            ),
                          ),
                          if (_query.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _controller.clear();
                                setState(() => _query = '');
                              },
                              child: Icon(Icons.cancel, size: AppScale.s(18), color: AppColors.mutedForeground),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _query.trim().isEmpty ? _DefaultContent(onKeyword: (k) {
                _controller.text = k;
                setState(() => _query = k);
              }) : _results.isEmpty
                  ? Center(child: Text('未找到「$_query」相关商品', style: TextStyle(color: AppColors.mutedForeground)))
                  : ListView(
                      padding: EdgeInsets.all(AppScale.s(16)),
                      children: [
                        Text('找到 ${_results.length} 个结果', style: TextStyle(fontSize: AppScale.s(12), color: AppColors.mutedForeground)),
                        SizedBox(height: AppScale.s(12)),
                        ..._results.map((p) => _SearchResultTile(product: p)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DefaultContent extends StatelessWidget {
  const _DefaultContent({required this.onKeyword});

  final ValueChanged<String> onKeyword;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(AppScale.s(16)),
      children: [
        Text('热门搜索', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
        SizedBox(height: AppScale.s(12)),
        Wrap(
          spacing: AppScale.s(8),
          runSpacing: AppScale.s(8),
          children: categoryTags.map((c) {
            return ActionChip(
              label: Text(c.name),
              backgroundColor: AppColors.secondary,
              side: BorderSide.none,
              onPressed: () => onKeyword(c.name),
            );
          }).toList(),
        ),
        SizedBox(height: AppScale.s(24)),
        Text('全部商品', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
        SizedBox(height: AppScale.s(12)),
        ...products.map((p) => _SearchResultTile(product: p)),
      ],
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailPage(product: product))),
      child: Container(
        margin: EdgeInsets.only(bottom: AppScale.s(10)),
        padding: EdgeInsets.all(AppScale.s(10)),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppScale.s(12)),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: [
            ProductThumbnail(product: product, width: AppScale.s(56), height: AppScale.s(56)),
            SizedBox(width: AppScale.s(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
                  Text(product.subCategory, style: TextStyle(fontSize: AppScale.s(11), color: AppColors.mutedForeground)),
                  Text('¥${product.price}', style: TextStyle(fontSize: AppScale.s(15), fontWeight: FontWeight.bold, color: AppColors.priceRed)),
                ],
              ),
            ),
            FilledButton(
              onPressed: () {
                context.read<CartProvider>().addItem(product);
                showTopSnackBar(context, content: Text('已加入购物车', style: TextStyle(fontWeight: FontWeight.w600)));
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: Size(AppScale.s(56), AppScale.s(32)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppScale.s(999))),
              ),
              child: Text('加购', style: TextStyle(fontSize: AppScale.s(12))),
            ),
          ],
        ),
      ),
    );
  }
}
