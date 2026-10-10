import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors.dart';
import '../data/attachments_repository.dart';
import '../domain/stock_transaction.dart';
import 'operations_controller.dart';
import '../../../core/l10n.dart';

const maxPhotos = 5;

typedef PickedImage = ({Uint8List bytes, String name});

/// Picks a photo (resized on device to keep uploads small).
/// Overridable in tests.
final imagePickerProvider =
    Provider<Future<PickedImage?> Function(ImageSource source)>(
      (_) => (source) async {
        final file = await ImagePicker().pickImage(
          source: source,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 80,
        );
        if (file == null) return null;
        return (bytes: await file.readAsBytes(), name: file.name);
      },
    );

/// Grid of evidence photos with add / view / delete.
class EvidencePhotos extends ConsumerStatefulWidget {
  const EvidencePhotos({super.key, required this.tx, required this.canEdit});

  final StockTransaction tx;
  final bool canEdit;

  @override
  ConsumerState<EvidencePhotos> createState() => _EvidencePhotosState();
}

class _EvidencePhotosState extends ConsumerState<EvidencePhotos> {
  double? _progress; // non-null while uploading

  Future<void> _add() async {
    final t = context.l10n;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(t.takePhoto),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(t.chooseGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final image = await ref.read(imagePickerProvider)(source);
      if (image == null || !mounted) return;

      setState(() => _progress = 0);
      await ref
          .read(attachmentsRepositoryProvider)
          .upload(
            widget.tx.id,
            image.bytes,
            image.name,
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
          );
      ref.invalidate(txDetailProvider(widget.tx.id));
      messenger.showSnackBar(SnackBar(content: Text(t.photoAttached)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiException.from(e).message)),
      );
    } finally {
      if (mounted) setState(() => _progress = null);
    }
  }

  void _open(int index) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _PhotoViewer(
          tx: widget.tx,
          initialIndex: index,
          canDelete: widget.canEdit,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photos = widget.tx.attachments;
    final canAdd =
        widget.canEdit &&
        widget.tx.status != TxStatus.cancelled &&
        photos.length < maxPhotos &&
        _progress == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              context.l10n.evidencePhotosCount(photos.length, maxPhotos),
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (photos.isEmpty && !canAdd && _progress == null)
          Text(
            context.l10n.noPhotosAttached,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < photos.length; i++)
                _Thumb(
                  key: Key('photo_${photos[i].id}'),
                  url: photos[i].thumbnailUrl(),
                  onTap: () => _open(i),
                ),
              if (_progress != null) _UploadingTile(progress: _progress!),
              if (canAdd) _AddTile(key: const Key('add_photo'), onTap: _add),
            ],
          ),
      ],
    );
  }
}

const _tileSize = 96.0;

class _Thumb extends StatelessWidget {
  const _Thumb({super.key, required this.url, required this.onTap});

  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: context.l10n.evidencePhoto,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: scheme.surfaceContainerHighest,
          child: InkWell(
            onTap: onTap,
            child: Image.network(
              url,
              width: _tileSize,
              height: _tileSize,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const SizedBox.square(
                      dimension: _tileSize,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
              errorBuilder: (_, _, _) => SizedBox.square(
                dimension: _tileSize,
                child: Icon(Icons.broken_image_outlined, color: scheme.outline),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: _tileSize,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_a_photo_outlined, color: scheme.primary),
            const SizedBox(height: 4),
            Text(context.l10n.addPhoto),
          ],
        ),
      ),
    );
  }
}

class _UploadingTile extends StatelessWidget {
  const _UploadingTile({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: _tileSize,
      height: _tileSize,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox.square(
            dimension: 32,
            child: CircularProgressIndicator(
              value: progress > 0 && progress < 1 ? progress : null,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            progress >= 1
                ? context.l10n.saving
                : '${(progress * 100).round()}%',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// Full-screen, zoomable photo pages with delete.
class _PhotoViewer extends ConsumerStatefulWidget {
  const _PhotoViewer({
    required this.tx,
    required this.initialIndex,
    required this.canDelete,
  });

  final StockTransaction tx;
  final int initialIndex;
  final bool canDelete;

  @override
  ConsumerState<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends ConsumerState<_PhotoViewer> {
  late final _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _deleting = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final t = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.deleteThisPhoto),
        content: Text(t.removedFromTx),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.back),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deleting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(attachmentsRepositoryProvider)
          .delete(widget.tx.id, widget.tx.attachments[_index].id);
      ref.invalidate(txDetailProvider(widget.tx.id));
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(t.photoDeleted)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiException.from(e).message)),
      );
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.tx.attachments;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${photos.length}'),
        actions: [
          if (widget.canDelete && widget.tx.status != TxStatus.cancelled)
            IconButton(
              key: const Key('delete_photo'),
              tooltip: context.l10n.deletePhoto,
              onPressed: _deleting ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: Image.network(
              photos[i].url,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, p) => p == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
              errorBuilder: (_, _, _) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 56,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
