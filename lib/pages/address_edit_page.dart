import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/product_data.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../theme/feature_page_style.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/feature_page_scaffold.dart';

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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.address?.name ?? '');
    _phoneController = TextEditingController(text: widget.address?.phone ?? '');
    _detailController = TextEditingController(text: widget.address?.detail ?? '');
    _isDefault = widget.address?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = await context.read<UserProvider>().saveAddress(
          id: widget.address?.id,
          name: _nameController.text.trim(),
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
          TextField(
            controller: _nameController,
            style: FeaturePageStyle.body(),
            decoration: _fieldDecoration('收货人'),
            maxLength: 20,
          ),
          TextField(
            controller: _phoneController,
            style: FeaturePageStyle.body(),
            decoration: _fieldDecoration('手机号'),
            keyboardType: TextInputType.phone,
            maxLength: 11,
          ),
          TextField(
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
          FilledButton(
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
