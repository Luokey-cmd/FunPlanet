import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_scale.dart';
import '../utils/snackbar_utils.dart';
import '../widgets/sparkle_background.dart';
import '../widgets/user_avatar_image.dart';
import 'image_preview_page.dart';

import '../widgets/click_effect/app_pressable.dart';
import '../widgets/click_effect/app_icon_button.dart';
import '../widgets/click_effect/app_buttons.dart';
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late String _selectedAvatar;
  // 性别存服务端原值：'' 未设置 / 'male' 男 / 'female' 女；生日为 yyyy-MM-dd，空 = 未设置。
  late String _gender;
  late String _birthday;
  Uint8List? _pendingAvatarBytes;
  String? _pendingAvatarMime;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>();
    _nameController = TextEditingController(text: user.nickname);
    _bioController = TextEditingController(text: user.bio);
    _selectedAvatar = user.avatarPath;
    _gender = user.gender;
    _birthday = user.birthday;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(_birthday) ?? DateTime(2000, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1950, 1, 1),
      lastDate: now,
    );
    if (picked == null) return;
    String two(int v) => v.toString().padLeft(2, '0');
    setState(() => _birthday = '${picked.year}-${two(picked.month)}-${two(picked.day)}');
  }

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      String? path = file.path;
      final ext = (file.extension?.isNotEmpty ?? false) ? file.extension!.toLowerCase() : 'jpg';
      final mimeType = ext == 'png'
          ? 'image/png'
          : ext == 'webp'
              ? 'image/webp'
              : ext == 'gif'
                  ? 'image/gif'
                  : 'image/jpeg';

      if (path == null || path.isEmpty) {
        final bytes = file.bytes;
        if (bytes == null) {
          if (!mounted) return;
          showTopSnackBar(
            context,
            content: Text('无法读取图片，请重试', style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
          );
          return;
        }
        final saved = File('${Directory.systemTemp.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext');
        await saved.writeAsBytes(bytes);
        path = saved.path;
        if (mounted) {
          setState(() {
            _selectedAvatar = path!;
            _pendingAvatarBytes = bytes;
            _pendingAvatarMime = mimeType;
          });
        }
        return;
      }

      final bytes = file.bytes ?? await File(path).readAsBytes();
      if (mounted) {
        setState(() {
          _selectedAvatar = path!;
          _pendingAvatarBytes = bytes;
          _pendingAvatarMime = mimeType;
        });
      }
    } catch (e) {
      if (!mounted) return;
      showTopSnackBar(
        context,
        content: Text('选择图片失败，请重试', style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
      );
    }
  }

  void _previewAvatar() {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (ctx) => ImagePreviewPage(
          backgroundColor: Colors.black,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppScale.s(16)),
            child: UserAvatarImage(
              path: _selectedAvatar,
              width: MediaQuery.sizeOf(ctx).width - AppScale.s(48),
              height: MediaQuery.sizeOf(ctx).width - AppScale.s(48),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final user = context.read<UserProvider>();
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showTopSnackBar(
        context,
        content: Text('昵称不能为空', style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
      );
      return;
    }
    final error = await user.saveProfile(
      nickname: name,
      avatarPath: _selectedAvatar,
      avatarBytes: _pendingAvatarBytes,
      avatarMimeType: _pendingAvatarMime,
      gender: _gender,
      birthday: _birthday,
      bio: _bioController.text.trim(),
    );
    if (!mounted) return;
    if (error != null) {
      showTopSnackBar(
        context,
        content: Text(error, style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
      );
      return;
    }
    showTopSnackBar(
      context,
      content: Text('资料已保存', style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
    );
    Navigator.pop(context);
  }

  BoxDecoration _fieldBoxDecoration() {
    return BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppScale.s(12)),
      border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
    );
  }

  // 性别选项：选中是紫底白字，未选中是卡片底色，和全 App 的小标签风格一致。
  Widget _genderChip(String value, String label) {
    final selected = _gender == value;
    return AppGestureDetector(
      onTap: () => setState(() => _gender = value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppScale.s(18), vertical: AppScale.s(8)),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(AppScale.s(999)),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border.withValues(alpha: 0.7)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: AppScale.t(14),
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.foreground,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SparkleBackground(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(AppScale.s(8), top + AppScale.s(8), AppScale.s(16), AppScale.s(8)),
              child: Row(
                children: [
                  AppIconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, size: AppScale.s(22), color: AppColors.foreground),
                  ),
                  Expanded(
                    child: Text(
                      '个人资料',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: AppScale.t(17), fontWeight: FontWeight.bold),
                    ),
                  ),
                  AppTextButton(
                    onPressed: _save,
                    child: Text('保存', style: TextStyle(fontSize: AppScale.t(15), fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppScale.s(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('头像', style: TextStyle(fontSize: AppScale.t(15), fontWeight: FontWeight.bold)),
                    SizedBox(height: AppScale.s(10)),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: AppScale.s(14), vertical: AppScale.s(10)),
                      decoration: _fieldBoxDecoration(),
                      child: Row(
                        children: [
                          AppGestureDetector(
                            onTap: _previewAvatar,
                            child: Container(
                              width: AppScale.s(52),
                              height: AppScale.s(52),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.6)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: UserAvatarImage(path: _selectedAvatar, fit: BoxFit.cover),
                            ),
                          ),
                          const Spacer(),
                          AppGestureDetector(
                            onTap: _pickAvatar,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: AppScale.s(8), horizontal: AppScale.s(4)),
                              child: Text(
                                '更换头像',
                                style: TextStyle(fontSize: AppScale.t(14), color: AppColors.primary, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppScale.s(24)),
                    Text('昵称', style: TextStyle(fontSize: AppScale.t(15), fontWeight: FontWeight.bold)),
                    SizedBox(height: AppScale.s(10)),
                    AppTextField(
                      controller: _nameController,
                      maxLength: 16,
                      decoration: InputDecoration(
                        hintText: '请输入昵称',
                        filled: true,
                        fillColor: AppColors.card,
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(horizontal: AppScale.s(14), vertical: AppScale.s(12)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppScale.s(12)),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppScale.s(12)),
                          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppScale.s(12)),
                          borderSide: BorderSide(color: AppColors.primary, width: AppScale.s(1.5)),
                        ),
                      ),
                      style: TextStyle(fontSize: AppScale.t(15)),
                    ),
                    SizedBox(height: AppScale.s(24)),
                    Text('性别', style: TextStyle(fontSize: AppScale.t(15), fontWeight: FontWeight.bold)),
                    SizedBox(height: AppScale.s(10)),
                    Row(
                      children: [
                        _genderChip('', '保密'),
                        SizedBox(width: AppScale.s(10)),
                        _genderChip('male', '男'),
                        SizedBox(width: AppScale.s(10)),
                        _genderChip('female', '女'),
                      ],
                    ),
                    SizedBox(height: AppScale.s(24)),
                    Text('生日', style: TextStyle(fontSize: AppScale.t(15), fontWeight: FontWeight.bold)),
                    SizedBox(height: AppScale.s(10)),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: AppScale.s(14), vertical: AppScale.s(12)),
                      decoration: _fieldBoxDecoration(),
                      child: Row(
                        children: [
                          Text(
                            _birthday.isEmpty ? '未设置' : _birthday,
                            style: TextStyle(
                              fontSize: AppScale.t(14),
                              color: _birthday.isEmpty ? AppColors.mutedForeground : AppColors.foreground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          if (_birthday.isNotEmpty)
                            AppGestureDetector(
                              onTap: () => setState(() => _birthday = ''),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: AppScale.s(6), vertical: AppScale.s(4)),
                                child: Text('清除', style: TextStyle(fontSize: AppScale.t(13), color: AppColors.mutedForeground)),
                              ),
                            ),
                          AppGestureDetector(
                            onTap: _pickBirthday,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: AppScale.s(4), vertical: AppScale.s(4)),
                              child: Text('选择日期', style: TextStyle(fontSize: AppScale.t(14), color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppScale.s(24)),
                    Text('简介', style: TextStyle(fontSize: AppScale.t(15), fontWeight: FontWeight.bold)),
                    SizedBox(height: AppScale.s(10)),
                    AppTextField(
                      controller: _bioController,
                      maxLength: 200,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: '介绍一下自己吧（选填）',
                        filled: true,
                        fillColor: AppColors.card,
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(horizontal: AppScale.s(14), vertical: AppScale.s(12)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppScale.s(12)),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppScale.s(12)),
                          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppScale.s(12)),
                          borderSide: BorderSide(color: AppColors.primary, width: AppScale.s(1.5)),
                        ),
                      ),
                      style: TextStyle(fontSize: AppScale.t(15)),
                    ),
                    SizedBox(height: AppScale.s(24)),
                    Text('账号信息', style: TextStyle(fontSize: AppScale.t(15), fontWeight: FontWeight.bold)),
                    SizedBox(height: AppScale.s(10)),
                    _InfoTile(label: '用户 ID', value: user.userId),
                    _InfoTile(label: '会员等级', value: 'VIP${user.vipLevel}'),
                    _InfoTile(label: '积分', value: '${user.points}'),
                    _InfoTile(label: '趣玩币', value: '${user.funCoins}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: AppScale.s(8)),
      padding: EdgeInsets.symmetric(horizontal: AppScale.s(14), vertical: AppScale.s(12)),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppScale.s(12)),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: AppScale.t(14), color: AppColors.mutedForeground)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: AppScale.t(14), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
