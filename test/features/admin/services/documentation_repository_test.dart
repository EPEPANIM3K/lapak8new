import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lapak8new/core/storage/storage_config.dart';
import 'package:lapak8new/features/admin/models/return_documentation.dart';
import 'package:lapak8new/features/admin/services/documentation_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('uploads evidence to its private Supabase Storage object path', () async {
    final requests = <http.Request>[];
    final supabase = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({'Key': 'return-documentation/inspection-id/photo-id'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final repository = DocumentationRepository(client: supabase);

    final uploaded = await repository.uploadFile(
      returnId: 'inspection-id',
      borrowingId: 'borrowing-id',
      itemId: 'item-id',
      file: const PendingDocumentationFile(
        id: 'photo-id',
        kind: DocumentationKind.photo,
        localPath: '',
        fileName: 'condition.gif',
        bytes: [1, 2, 3],
        size: 3,
      ),
    );

    expect(requests, hasLength(1));
    expect(
      requests.single.url.path,
      '/storage/v1/object/${Lapak8StorageConfig.bucket}/inspection-id/photo-id',
    );
    expect(
      utf8.decode(requests.single.bodyBytes, allowMalformed: true),
      contains('content-type: image/gif'),
    );
    expect(uploaded.path, 'inspection-id/photo-id');
  });

  test('rejects unsupported extensions before accessing Supabase', () async {
    final repository = DocumentationRepository();

    await expectLater(
      repository.uploadFile(
        returnId: 'inspection-id',
        borrowingId: 'borrowing-id',
        itemId: 'item-id',
        file: const PendingDocumentationFile(
          id: 'file-id',
          kind: DocumentationKind.photo,
          localPath: '',
          fileName: 'condition.svg',
          bytes: [1],
          size: 1,
        ),
      ),
      throwsA(
        isA<StorageApiException>().having(
          (error) => error.code,
          'code',
          'unsupported_format',
        ),
      ),
    );
  });

  test('rejects evidence larger than the configured upload limit', () async {
    final repository = DocumentationRepository();

    await expectLater(
      repository.uploadFile(
        returnId: 'inspection-id',
        borrowingId: 'borrowing-id',
        itemId: 'item-id',
        file: PendingDocumentationFile(
          id: 'file-id',
          kind: DocumentationKind.photo,
          localPath: '',
          fileName: 'condition.jpg',
          bytes: const [1],
          size: Lapak8StorageConfig.maxPhotoBytes + 1,
        ),
      ),
      throwsA(
        isA<StorageApiException>().having(
          (error) => error.code,
          'code',
          'file_too_large',
        ),
      ),
    );
  });
}
