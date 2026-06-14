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

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final TextEditingController _nameController;
  late String _selectedAvatar;
  Uint8List? _pendingAvatarBytes;
  String? _pendingAvatarMime;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>();
    _nameController = TextEditingController(text: user.nickname);
    _selectedAvatar = user.avatarPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
            content: Text('无法读取图片，请重试', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
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
        content: Text('选择图片失败，请重试', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
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
        content: Text('昵称不能为空', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
      );
      return;
    }
    final error = await user.saveProfile(
      nickname: name,
      avatarPath: _selectedAvatar,
      avatarBytes: _pendingAvatarBytes,
      avatarMimeType: _pendingAvatarMime,
    );
    if (!mounted) return;
    if (error != null) {
      showTopSnackBar(
        context,
        content: Text(error, style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
      );
      return;
    }
    showTopSnackBar(
      context,
      content: Text('资料已保存', style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
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
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, size: AppScale.s(22), color: AppColors.foreground),
                  ),
                  Expanded(
                    child: Text(
                      '个人资料',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: AppScale.s(17), fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: _save,
                    child: Text('保存', style: TextStyle(fontSize: AppScale.s(15), fontWeight: FontWeight.w600, color: AppColors.primary)),
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
                    Text('头像', style: TextStyle(fontSize: AppScale.s(15), fontWeight: FontWeight.bold)),
                    SizedBox(height: AppScale.s(10)),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: AppScale.s(14), vertical: AppScale.s(10)),
                      decoration: _fieldBoxDecoration(),
                      child: Row(
                        children: [
                          GestureDetector(
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
                          GestureDetector(
                            onTap: _pickAvatar,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: AppScale.s(8), horizontal: AppScale.s(4)),
                              child: Text(
                                '更换头像',
                                style: TextStyle(fontSize: AppScale.s(14), color: AppColors.primary, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: AppScale.s(24)),
                    Text('昵称', style: TextStyle(fontSize: AppScale.s(15), fontWeight: FontWeight.bold)),
                    SizedBox(height: AppScale.s(10)),
                    TextField(
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
                      style: TextStyle(fontSize: AppScale.s(15)),
                    ),
                    SizedBox(height: AppScale.s(24)),
                    Text('账号信息', style: TextStyle(fontSize: AppScale.s(15), fontWeight: FontWeight.bold)),
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
          Text(label, style: TextStyle(fontSize: AppScale.s(14), color: AppColors.mutedForeground)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: AppScale.s(14), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
