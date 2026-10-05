import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wister_lite/app/data/models/app_user.dart';
import 'package:wister_lite/app/data/services/ad_service.dart';
import 'package:wister_lite/app/data/services/sync_service.dart';
import 'package:wister_lite/app/theme/app_theme.dart';
import 'package:wister_lite/app/ui/ui.dart';

import '../controllers/profile_controller.dart';
import 'package:wister_lite/app/translations/tr_context.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profil'.tr)),
      body: Obx(() {
        final user = controller.auth.user.value;
        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s8, AppSpacing.page, AppSpacing.s48),
          children: [
            if (user == null) _GuestCard(busy: controller.isBusy.value, onSignIn: controller.signIn) else _AccountCard(user: user),
            const SizedBox(height: AppSpacing.section),
            _SectionTitle('Sinkronisasi'.tr),
            const _SyncCard(),
            if (user != null) ...[
              const SizedBox(height: AppSpacing.section),
              _SectionTitle('Akun'.tr),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      enabled: !controller.isBusy.value,
                      leading: const Icon(AppIcons.signOut),
                      title: Text('Keluar'.trIn('auth')),
                      subtitle: Text('Data di HP ini ikut dihapus'.tr),
                      onTap: () => _confirmSignOut(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      enabled: !controller.isBusy.value,
                      iconColor: context.colors.danger,
                      textColor: context.colors.danger,
                      leading: const Icon(AppIcons.trash),
                      title: Text('Hapus akun'.tr),
                      subtitle: Text('Hapus akun dan semua data di server'.tr),
                      onTap: () => _confirmDeleteAccount(context),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      }),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final message = await controller.prepareSignOut();
    if (!context.mounted) return;
    final ok = await ConfirmDialog.show(context, title: 'Keluar dari akun?'.tr, message: message, confirmLabel: 'Keluar'.trIn('auth'));
    if (ok) await controller.signOut();
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'Hapus akun?'.tr,
      message: 'Akun dan semua data di server dihapus permanen, begitu juga data di HP ini. Tindakan ini tidak bisa dibatalkan.'.tr,
      confirmLabel: 'Hapus akun'.tr,
    );
    if (ok) await controller.deleteAccount();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: AppSpacing.s4, bottom: AppSpacing.s8),
    child: Semantics(
      header: true,
      child: Text(text, style: context.text.titleSmall?.copyWith(color: context.colors.inkMuted)),
    ),
  );
}

/// Belum masuk: ajakan masuk dengan Google.
class _GuestCard extends StatelessWidget {
  const _GuestCard({required this.busy, required this.onSignIn});

  final bool busy;
  final Future<bool> Function() onSignIn;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Card(
      color: c.brandContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: Column(
          children: [
            AppIllustration.dompi(DompiMood.senang, size: 96),
            const SizedBox(height: AppSpacing.s12),
            Text(
              'Datamu cuma ada di HP ini'.tr,
              textAlign: TextAlign.center,
              style: context.text.titleLarge?.copyWith(color: c.onBrandContainer),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Masuk dengan Google untuk mencadangkan catatan ke server dan membukanya di HP lain.'.tr,
              textAlign: TextAlign.center,
              style: context.text.bodySmall?.copyWith(color: c.onBrandContainer),
            ),
            const SizedBox(height: AppSpacing.s20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : onSignIn,
                icon: busy
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(AppIcons.googleLogo),
                label: Text('Masuk dengan Google'.tr),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final avatarUrl = user.avatarUrl;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.card),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: c.brandContainer,
              foregroundColor: c.onBrandContainer,
              foregroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: Text(user.initial, style: context.text.titleLarge?.copyWith(color: c.onBrandContainer)),
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium?.copyWith(color: c.ink)),
                  const SizedBox(height: AppSpacing.s2),
                  Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall?.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Saklar "Iklan & sinkronisasi", status sync, dan jatah iklan hari ini.
class _SyncCard extends GetView<ProfileController> {
  const _SyncCard();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Obx(() {
      final on = controller.syncOn;
      final signedIn = controller.auth.isSignedIn;
      return Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            SwitchListTile(
              value: on,
              onChanged: controller.isBusy.value ? null : controller.toggleSync,
              secondary: Icon(AppIcons.cloudArrowUp, color: on ? c.brand : c.inkMuted),
              title: Text('Iklan & sinkronisasi'.tr),
              subtitle: Text(
                'Tampilkan iklan video paling cepat tiap @n jam untuk mencadangkan data ke server secara otomatis.'.trParams({
                  'n': '${AdService.minGap.inHours}',
                }),
              ),
            ),
            if (on) ...[
              const Divider(height: 1),
              const _SyncStatusTile(),
              const Divider(height: 1),
              ListTile(
                leading: Icon(AppIcons.playCircle, color: c.inkMuted),
                title: Text('Iklan hari ini'.tr),
                subtitle: Text('Paling cepat tiap @n jam'.trParams({'n': '${AdService.minGap.inHours}'})),
                trailing: Text(
                  '${controller.ads.shownToday.value}',
                  style: context.text.labelLarge?.copyWith(color: c.inkMuted),
                ),
              ),
            ] else if (signedIn) ...[
              const Divider(height: 1),
              ListTile(
                leading: Icon(AppIcons.cloudSlash, color: c.inkMuted),
                title: Text('Sinkronisasi mati'.tr),
                subtitle: Text('Catatan baru hanya tersimpan di HP ini.'.tr),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _SyncStatusTile extends GetView<ProfileController> {
  const _SyncStatusTile();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sync = controller.sync;
    return Obx(() {
      final state = sync.state.value;
      final pending = sync.pendingCount.value;
      final last = sync.lastSyncedAt.value;
      final lastText = last == null ? 'Belum pernah disinkronkan'.tr : 'Terakhir @time'.trParams({'time': _relative(last)});

      final (IconData icon, Color color, String title, String subtitle) = switch (state) {
        SyncState.syncing => (AppIcons.arrowsClockwise, c.brand, 'Menyinkronkan…'.tr, lastText),
        SyncState.offline => (AppIcons.cloudSlash, c.warning, 'Tidak ada koneksi'.tr, 'Dicoba lagi saat ada perubahan berikutnya'.tr),
        SyncState.error => (AppIcons.cloudWarning, c.danger, 'Sinkronisasi gagal'.tr, sync.errorMessage.value?.tr ?? lastText),
        SyncState.idle when pending > 0 => (AppIcons.cloudArrowUp, c.warning, '@n perubahan menunggu'.trParams({'n': '$pending'}), lastText),
        SyncState.idle => (AppIcons.cloudCheck, c.income, last == null ? 'Siap disinkronkan'.tr : 'Semua data tersinkron'.tr, lastText),
      };

      return ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: state == SyncState.syncing
            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : TextButton(onPressed: controller.syncNow, child: Text('Sinkronkan'.tr)),
      );
    });
  }

  static String _relative(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'baru saja'.tr;
    if (diff.inHours < 1) return '@n menit lalu'.trParams({'n': '${diff.inMinutes}'});
    if (diff.inDays < 1) return '@n jam lalu'.trParams({'n': '${diff.inHours}'});
    final hm = '${time.hour.toString().padLeft(2, '0')}.${time.minute.toString().padLeft(2, '0')}';
    return '${AppFormat.dayMonthShort(time)}, $hm';
  }
}
