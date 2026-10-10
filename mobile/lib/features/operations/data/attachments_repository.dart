import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/errors.dart';

final attachmentsRepositoryProvider = Provider<AttachmentsRepository>(
  (ref) => ApiAttachmentsRepository(
    ref.watch(dioProvider),
    // Separate client for Cloudinary: it must never receive our JWT.
    Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 30),
      ),
    ),
  ),
);

abstract class AttachmentsRepository {
  /// Uploads straight to Cloudinary with a server-signed request, then
  /// records it on the transaction. [onProgress] reports 0..1.
  Future<void> upload(
    String txId,
    Uint8List bytes,
    String filename, {
    void Function(double progress)? onProgress,
  });

  Future<void> delete(String txId, String attachmentId);
}

class ApiAttachmentsRepository implements AttachmentsRepository {
  ApiAttachmentsRepository(this._api, this._cdn);

  final Dio _api;
  final Dio _cdn;

  @override
  Future<void> upload(
    String txId,
    Uint8List bytes,
    String filename, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      // 1. Ask our API for a short-lived upload signature.
      final sig = (await _api.post<Map<String, dynamic>>(
        '/transactions/$txId/attachments/signature',
      )).data!;

      // 2. Upload the file directly to Cloudinary.
      final uploaded = (await _cdn.post<Map<String, dynamic>>(
        sig['uploadUrl'] as String,
        // Send exactly the fields the server signed (format/size limits
        // included); changing any of them makes Cloudinary reject the upload.
        data: FormData.fromMap({
          ...(sig['fields'] as Map<String, dynamic>),
          'file': MultipartFile.fromBytes(bytes, filename: filename),
        }),
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
      )).data!;

      // 3. Record it; the API verifies it's really in this transaction's folder.
      await _api.post<void>(
        '/transactions/$txId/attachments',
        data: {
          'publicId': uploaded['public_id'],
          'url': uploaded['secure_url'],
        },
      );
    } catch (e) {
      throw _uploadError(e);
    }
  }

  @override
  Future<void> delete(String txId, String attachmentId) async {
    try {
      await _api.delete<void>('/transactions/$txId/attachments/$attachmentId');
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  /// Cloudinary errors look like { error: { message } }.
  ApiException _uploadError(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['error'] is Map) {
        return ApiException(
          'Upload failed: ${(data['error'] as Map)['message']}',
          statusCode: e.response?.statusCode,
        );
      }
    }
    return ApiException.from(e);
  }
}
