import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/product_data.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/feature_page_style.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/feature_page_scaffold.dart';

import '../widgets/click_effect/app_buttons.dart';
import '../widgets/click_effect/app_pressable.dart';
class AddressEditPage extends StatefulWidget {
  const AddressEditPage({super.key, this.address});

  final Address? address;

  @override
  State<AddressEditPage> createState() => _AddressEditPageState();
}

class _AddressEditPageState extends State<AddressEditPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _detailController;
  late bool _isDefault;

  // 新增地址时收货人预填的后缀提示：只是告诉用户这名字能改，
  // 保存时会自动摘掉，不会把提示存进地址里（见 _save）。
  static const _prefillHint = '（可修改）';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.address?.name ?? '');
    _phoneController = TextEditingController(text: widget.address?.phone ?? '');
    _detailController = TextEditingController(text: widget.address?.detail ?? '');
    _isDefault = widget.address?.isDefault ?? false;
  }

  bool _prefilled = false;

  // 新增地址才预填：收货人先写用户昵称、手机号先写注册手机号，
  // 都是「先替他填上、他想改再改」；编辑已有地址不碰原值。
  // 放在 didChangeDependencies 里读账号信息（此时 Provider 已就绪），只跑一次。
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_prefilled || widget.address != null) return;
    _prefilled = true;
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    if (_nameController.text.isEmpty && user.nickname.isNotEmpty) {
      _nameController.text = '${user.nickname}$_prefillHint';
    }
    if (_phoneController.text.isEmpty && user.phone.isNotEmpty) {
      _phoneController.text = user.phone;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // 收货人末尾若还挂着预填提示，说明用户没动这格：存纯昵称，别把提示存进去；
    // 用户自己改过（提示已被删改）就按他写的内容原样存。
    var name = _nameController.text.trim();
    if (name.endsWith(_prefillHint)) {
      name = name.substring(0, name.length - _prefillHint.length).trim();
    }
    final error = await context.read<UserProvider>().saveAddress(
          id: widget.address?.id,
          name: name,
          phone: _phoneController.text.trim(),
          detail: _detailController.text.trim(),
          isDefault: _isDefault,
        );
    if (!mounted) return;
    if (error != null) {
      showTopSnackBar(
        context,
        content: Text(error, style: FeaturePageStyle.bodyBold()),
      );
      return;
    }
    Navigator.pop(context);
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: FeaturePageStyle.secondary(),
      contentPadding: EdgeInsets.symmetric(horizontal: AppScale.s(4), vertical: AppScale.s(14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FeaturePageScaffold(
      title: widget.address == null ? '新增地址' : '编辑地址',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _nameController,
            style: FeaturePageStyle.body(),
            decoration: _fieldDecoration('收货人'),
            maxLength: 20,
          ),
          AppTextField(
            controller: _phoneController,
            style: FeaturePageStyle.body(),
            decoration: _fieldDecoration('手机号'),
            keyboardType: TextInputType.phone,
            maxLength: 11,
          ),
          AppTextField(
            controller: _detailController,
            style: FeaturePageStyle.body(),
            decoration: _fieldDecoration('详细地址'),
            maxLines: 3,
            maxLength: 120,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('设为默认地址', style: FeaturePageStyle.bodyBold()),
            value: _isDefault,
            activeColor: AppColors.primary,
            onChanged: (value) => setState(() => _isDefault = value ?? false),
          ),
          SizedBox(height: AppScale.s(16)),
          AppFilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: Size(double.infinity, FeaturePageStyle.buttonHeight),
            ),
            child: Text('保存', style: FeaturePageStyle.buttonLabel(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
