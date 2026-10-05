import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wister_lite/app/data/models/app_user.dart';
import 'package:wister_lite/app/data/services/ad_service.dart';
import 'package:wister_lite/app/data/services/sync_service.dart';
import 'package:wister_lite/app/theme/app_theme.dart';
import 'package:wister_lite/app/ui/ui.dart';

import '../controllers/profile_controller.dart';

class ProfileView extends GetView<ProfileController> {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: Obx(() {
        final user = controller.auth.user.value;
        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.s8, AppSpacing.page, AppSpacing.s48),
          children: [
            if (user == null) _GuestCard(busy: controller.isBusy.value, onSignIn: controller.signIn) else _AccountCard(user: user),
            const SizedBox(height: AppSpacing.section),
            const _SectionTitle('Sinkronisasi'),
            const _SyncCard(),
            if (user != null) ...[
              const SizedBox(height: AppSpacing.section),
              const _SectionTitle('Akun'),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      enabled: !controller.isBusy.value,
                      leading: const Icon(AppIcons.signOut),
                      title: const Text('Keluar'),
                      subtitle: const Text('Data di HP ini ikut dihapus'),
                      onTap: () => _confirmSignOut(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      enabled: !controller.isBusy.value,
                      iconColor: context.colors.danger,
                      textColor: context.colors.danger,
                      leading: const Icon(AppIcons.trash),
                      title: const Text('Hapus akun'),
                      subtitle: const Text('Hapus akun dan semua data di server'),
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
    final ok = await ConfirmDialog.show(context, title: 'Keluar dari akun?', message: message, confirmLabel: 'Keluar');
    if (ok) await controller.signOut();
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'Hapus akun?',
      message: 'Akun dan semua data di server dihapus permanen, begitu juga data di HP ini. Tindakan ini tidak bisa dibatalkan.',
      confirmLabel: 'Hapus akun',
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
              'Datamu cuma ada di HP ini',
              textAlign: TextAlign.center,
              style: context.text.titleLarge?.copyWith(color: c.onBrandContainer),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Masuk dengan Google untuk mencadangkan catatan ke server dan membukanya di HP lain.',
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
                label: const Text('Masuk dengan Google'),
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
              title: const Text('Iklan & sinkronisasi'),
              subtitle: Text(
                'Tampilkan maksimal ${AdService.dailyLimit} iklan video sehari untuk mencadangkan data ke server secara otomatis.',
              ),
            ),
            if (on) ...[
              const Divider(height: 1),
              const _SyncStatusTile(),
              const Divider(height: 1),
              ListTile(
                leading: Icon(AppIcons.playCircle, color: c.inkMuted),
                title: const Text('Iklan hari ini'),
                subtitle: const Text('Jatah kembali penuh setiap tengah malam'),
                trailing: _AdQuota(shown: controller.ads.shownToday.value),
              ),
            ] else if (signedIn) ...[
              const Divider(height: 1),
              ListTile(
                leading: Icon(AppIcons.cloudSlash, color: c.inkMuted),
                title: const Text('Sinkronisasi mati'),
                subtitle: const Text('Catatan baru hanya tersimpan di HP ini.'),
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
      final lastText = last == null ? 'Belum pernah disinkronkan' : 'Terakhir ${_relative(last)}';

      final (IconData icon, Color color, String title, String subtitle) = switch (state) {
        SyncState.syncing => (AppIcons.arrowsClockwise, c.brand, 'Menyinkronkan…', lastText),
        SyncState.offline => (AppIcons.cloudSlash, c.warning, 'Tidak ada koneksi', 'Dicoba lagi saat ada perubahan berikutnya'),
        SyncState.error => (AppIcons.cloudWarning, c.danger, 'Sinkronisasi gagal', sync.errorMessage.value ?? lastText),
        SyncState.idle when pending > 0 => (AppIcons.cloudArrowUp, c.warning, '$pending perubahan menunggu', lastText),
        SyncState.idle => (AppIcons.cloudCheck, c.income, last == null ? 'Siap disinkronkan' : 'Semua data tersinkron', lastText),
      };

      return ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: state == SyncState.syncing
            ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : TextButton(onPressed: controller.syncNow, child: const Text('Sinkronkan')),
      );
    });
  }

  static String _relative(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
    if (diff.inDays < 1) return '${diff.inHours} jam lalu';
    final hm = '${time.hour.toString().padLeft(2, '0')}.${time.minute.toString().padLeft(2, '0')}';
    return '${AppFormat.dayMonthShort(time)}, $hm';
  }
}

/// Titik per jatah iklan: terisi = sudah tampil hari ini.
class _AdQuota extends StatelessWidget {
  const _AdQuota({required this.shown});

  final int shown;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: '$shown dari ${AdService.dailyLimit} iklan hari ini',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < AdService.dailyLimit; i++)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(left: AppSpacing.s4),
              decoration: BoxDecoration(shape: BoxShape.circle, color: i < shown ? c.brand : c.outlineVariant),
            ),
          const SizedBox(width: AppSpacing.s8),
          Text('$shown/${AdService.dailyLimit}', style: context.text.labelLarge?.copyWith(color: c.inkMuted)),
        ],
      ),
    );
  }
}
