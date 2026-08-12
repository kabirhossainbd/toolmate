import 'package:dio/dio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

enum MediaKind { video, image, gif }

class ResolvedMedia {
  final String sourceUrl;
  final String downloadUrl;
  final String title;
  final String thumbnailUrl;
  final String filename;
  final MediaKind kind;
  final String platform;

  const ResolvedMedia({
    required this.sourceUrl,
    required this.downloadUrl,
    required this.title,
    required this.thumbnailUrl,
    required this.filename,
    required this.kind,
    required this.platform,
  });

  bool get isImageLike => kind == MediaKind.image || kind == MediaKind.gif;
}

class MediaResolveResult {
  final List<ResolvedMedia> items;
  final String? error;

  const MediaResolveResult({required this.items, this.error});

  bool get isSuccess => items.isNotEmpty;
}

/// Resolves downloadable media from social platforms via Cobalt + native extractors.
class SocialMediaService {
  SocialMediaService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Public Cobalt-compatible instances (no auth). Tried in order.
  static const List<String> cobaltInstances = [
    'https://api.cobalt.liubquanti.click/',
    'https://cobalt-backend.canine.tools/',
  ];

  static const supportedPlatforms = [
    'YouTube',
    'Instagram',
    'TikTok',
    'Facebook',
    'X / Twitter',
    'Pinterest',
    'Reddit',
    'Snapchat',
    'Threads',
    'Vimeo',
  ];

  String detectPlatform(String url) {
    final host = (Uri.tryParse(url)?.host ?? '').toLowerCase();
    if (host.contains('youtube') || host.contains('youtu.be')) return 'YouTube';
    if (host.contains('instagram')) return 'Instagram';
    if (host.contains('tiktok') || host.contains('vm.tiktok')) return 'TikTok';
    if (host.contains('facebook') || host.contains('fb.watch') || host == 'fb.com') {
      return 'Facebook';
    }
    if (host.contains('twitter') || host == 'x.com' || host.endsWith('.x.com')) {
      return 'X / Twitter';
    }
    if (host.contains('pinterest') || host.contains('pin.it')) return 'Pinterest';
    if (host.contains('reddit') || host.contains('redd.it')) return 'Reddit';
    if (host.contains('snapchat')) return 'Snapchat';
    if (host.contains('threads')) return 'Threads';
    if (host.contains('vimeo')) return 'Vimeo';
    if (host.contains('linkedin')) return 'LinkedIn';
    if (host.contains('tumblr')) return 'Tumblr';
    if (host.contains('soundcloud')) return 'SoundCloud';
    return host.isEmpty ? 'Unknown' : host;
  }

  bool isDirectMediaUrl(String url) {
    final path = (Uri.tryParse(url)?.path ?? '').toLowerCase();
    return path.endsWith('.mp4') ||
        path.endsWith('.webm') ||
        path.endsWith('.mov') ||
        path.endsWith('.m4v') ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
        path.endsWith('.gif');
  }

  Future<MediaResolveResult> resolve(String url) async {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (trimmed.isEmpty || uri == null || !uri.hasScheme) {
      return const MediaResolveResult(
        items: [],
        error: 'Please enter a valid URL',
      );
    }

    final platform = detectPlatform(trimmed);

    if (isDirectMediaUrl(trimmed)) {
      return MediaResolveResult(items: [_fromDirectUrl(trimmed, platform)]);
    }

    // YouTube: prefer local extractor (more reliable quality selection).
    if (platform == 'YouTube') {
      final yt = await _resolveYouTube(trimmed);
      if (yt.isSuccess) return yt;
      // Fall through to Cobalt if explode fails.
    }

    // TikTok: try public TikWM-style extractor first (no Cobalt auth needed).
    if (platform == 'TikTok') {
      final tt = await _resolveTikTok(trimmed);
      if (tt.isSuccess) return tt;
      // Fall through to Cobalt if it fails.
    }

    // Facebook: try legacy v7 endpoint first (handles share/v and share/r links).
    if (platform == 'Facebook') {
      final fb = await _resolveV7Fallback(trimmed, platform);
      if (fb != null && fb.isSuccess) return fb;
    }

    // Best-effort fallback for other platforms.
    if (platform != 'YouTube' && platform != 'Facebook') {
      final v7 = await _resolveV7Fallback(trimmed, platform);
      if (v7 != null && v7.isSuccess) return v7;
    }

    // Twitter/X: try FixTweet-style API first.
    if (platform == 'X / Twitter') {
      final tw = await _resolveTwitter(trimmed);
      if (tw.isSuccess) return tw;
    }

    final cobalt = await _resolveCobalt(trimmed, platform);
    if (cobalt.isSuccess) return cobalt;

    // Last resort: YouTube already tried; return best error.
    if (platform == 'YouTube') {
      return const MediaResolveResult(
        items: [],
        error: 'Failed to fetch YouTube video. Try another link.',
      );
    }

    return MediaResolveResult(
      items: [],
      error: cobalt.error ??
          'Could not fetch media from $platform. Make sure the post is public.',
    );
  }

  ResolvedMedia _fromDirectUrl(String url, String platform) {
    final path = Uri.parse(url).path.toLowerCase();
    final kind = _kindFromPath(path);
    final name = Uri.parse(url).pathSegments.isNotEmpty
        ? Uri.parse(url).pathSegments.last
        : 'media_${DateTime.now().millisecondsSinceEpoch}';
    return ResolvedMedia(
      sourceUrl: url,
      downloadUrl: url,
      title: name,
      thumbnailUrl: kind == MediaKind.image || kind == MediaKind.gif ? url : '',
      filename: name,
      kind: kind,
      platform: platform,
    );
  }

  MediaKind _kindFromPath(String path) {
    if (path.endsWith('.gif')) return MediaKind.gif;
    if (path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp')) {
      return MediaKind.image;
    }
    return MediaKind.video;
  }

  MediaKind _kindFromType(String? type, String filename) {
    final t = (type ?? '').toLowerCase();
    if (t == 'photo' || t == 'image') return MediaKind.image;
    if (t == 'gif') return MediaKind.gif;
    if (t == 'video') return MediaKind.video;
    return _kindFromPath(filename.toLowerCase());
  }

  Future<MediaResolveResult> _resolveYouTube(String url) async {
    final yt = YoutubeExplode();
    try {
      final video = await yt.videos.get(url);
      final manifest = await yt.videos.streamsClient.getManifest(url);
      final muxed = manifest.muxed;
      if (muxed.isEmpty) {
        return const MediaResolveResult(
          items: [],
          error: 'No downloadable YouTube stream found.',
        );
      }
      final stream = muxed.withHighestBitrate();
      final thumb = video.thumbnails.highResUrl.isNotEmpty
          ? video.thumbnails.highResUrl
          : video.thumbnails.mediumResUrl;
      final safeTitle = video.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      return MediaResolveResult(
        items: [
          ResolvedMedia(
            sourceUrl: url,
            downloadUrl: stream.url.toString(),
            title: video.title,
            thumbnailUrl: thumb,
            filename: '${safeTitle.isEmpty ? 'youtube' : safeTitle}.mp4',
            kind: MediaKind.video,
            platform: 'YouTube',
          ),
        ],
      );
    } catch (_) {
      return const MediaResolveResult(items: []);
    } finally {
      yt.close();
    }
  }

  Future<MediaResolveResult> _resolveTwitter(String url) async {
    final match = RegExp(r'status/(\d+)').firstMatch(url);
    if (match == null) return const MediaResolveResult(items: []);
    final id = match.group(1)!;

    for (final host in ['api.fxtwitter.com', 'api.vxtwitter.com']) {
      try {
        final res = await _dio.get<Map<String, dynamic>>(
          'https://$host/status/$id',
          options: Options(
            responseType: ResponseType.json,
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 15),
            validateStatus: (s) => s != null && s < 500,
          ),
        );
        final data = res.data;
        if (data == null) continue;
        final tweet = (data['tweet'] as Map?)?.cast<String, dynamic>() ?? data;
        final media = tweet['media'];
        final items = <ResolvedMedia>[];

        void addFromList(dynamic list, MediaKind kind) {
          if (list is! List) return;
          for (final m in list) {
            if (m is! Map) continue;
            final map = m.cast<String, dynamic>();
            final dl = (map['url'] ?? map['download_url'] ?? '').toString();
            if (dl.isEmpty) continue;
            final thumb = (map['thumbnail_url'] ?? map['preview_url'] ?? dl).toString();
            items.add(
              ResolvedMedia(
                sourceUrl: url,
                downloadUrl: dl,
                title: (tweet['text'] ?? tweet['title'] ?? 'Twitter media').toString(),
                thumbnailUrl: thumb,
                filename: dl.split('/').last.split('?').first,
                kind: kind,
                platform: 'X / Twitter',
              ),
            );
          }
        }

        if (media is Map) {
          addFromList(media['videos'], MediaKind.video);
          addFromList(media['photos'], MediaKind.image);
          addFromList(media['gifs'], MediaKind.gif);
        }

        // vxtwitter shape: mediaURLs / media_extended
        final mediaUrls = tweet['mediaURLs'] ?? tweet['mediaUrls'];
        if (items.isEmpty && mediaUrls is List) {
          for (final u in mediaUrls) {
            final dl = u.toString();
            if (dl.isEmpty) continue;
            items.add(
              ResolvedMedia(
                sourceUrl: url,
                downloadUrl: dl,
                title: (tweet['text'] ?? 'Twitter media').toString(),
                thumbnailUrl: dl,
                filename: dl.split('/').last.split('?').first,
                kind: _kindFromPath(dl.toLowerCase()),
                platform: 'X / Twitter',
              ),
            );
          }
        }

        if (items.isNotEmpty) {
          return MediaResolveResult(items: items);
        }
      } catch (_) {
        // try next host
      }
    }
    return const MediaResolveResult(items: []);
  }

  Future<MediaResolveResult> _resolveTikTok(String url) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        'https://tikwm.com/api/',
        queryParameters: {
          'url': url,
          // Prefer highest quality when available.
          'hd': '1',
        },
        options: Options(
          responseType: ResponseType.json,
          headers: const {
            'Accept': 'application/json',
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
          receiveTimeout: const Duration(seconds: 25),
          sendTimeout: const Duration(seconds: 15),
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      final data = res.data;
      if (data == null) return const MediaResolveResult(items: []);
      if (data['code']?.toString() != '0') return const MediaResolveResult(items: []);

      final payload = (data['data'] is Map) ? data['data'] as Map : null;
      if (payload == null) return const MediaResolveResult(items: []);

      final downloadUrl =
          payload['hdplay']?.toString().isNotEmpty == true
              ? payload['hdplay'].toString()
              : payload['play']?.toString();
      if (downloadUrl == null || downloadUrl.isEmpty) {
        return const MediaResolveResult(items: []);
      }

      final title = payload['title']?.toString().trim();
      final cover = payload['cover']?.toString() ?? '';
      final id = payload['id']?.toString() ?? '';

      final fileBase = title != null && title.isNotEmpty
          ? title
          : (id.isNotEmpty ? 'tiktok_$id' : 'tiktok');
      final safeName = fileBase
          .replaceAll(RegExp(r'[^\w\s.\-]'), '_')
          .replaceAll(RegExp(r'\s+'), '_')
          .trim();

      final filename = safeName.endsWith('.mp4')
          ? safeName
          : '${safeName}_${downloadUrl.split('/').last.split('?').first}.mp4';

      return MediaResolveResult(
        items: [
          ResolvedMedia(
            sourceUrl: url,
            downloadUrl: downloadUrl,
            title: title != null && title.isNotEmpty ? title : 'TikTok video',
            thumbnailUrl: cover,
            filename: filename,
            kind: MediaKind.video,
            platform: 'TikTok',
          ),
        ],
      );
    } on DioException {
      return const MediaResolveResult(items: []);
    } catch (_) {
      return const MediaResolveResult(items: []);
    }
  }

  /// Tries a legacy/non-auth Cobalt v7-compatible endpoint.
  ///
  /// Returns a successful result on `stream`/`redirect`, otherwise `null` so
  /// other providers (e.g. Cobalt v10) can be tried.
  Future<MediaResolveResult?> _resolveV7Fallback(
    String url,
    String platform,
  ) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        'https://downloadapi.stuff.solutions/api/json',
        data: {
          'url': url,
          'vQuality': '1080',
        },
        options: Options(
          responseType: ResponseType.json,
          headers: const {
            // Must be exactly this — broader Accept values are rejected.
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          },
          receiveTimeout: const Duration(seconds: 25),
          sendTimeout: const Duration(seconds: 15),
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      final data = res.data;
      if (data == null) return null;

      final status = data['status']?.toString();
      if (status == 'stream' || status == 'redirect') {
        final downloadUrl = data['url']?.toString() ?? '';
        if (downloadUrl.isEmpty) return null;

        final ext = downloadUrl.toLowerCase().contains('.mp4') ? 'mp4' : 'mp4';
        final filename =
            '${platform.toLowerCase().replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.$ext';

        return MediaResolveResult(
          items: [
            ResolvedMedia(
              sourceUrl: url,
              downloadUrl: downloadUrl,
              title: '$platform video',
              thumbnailUrl: '',
              filename: filename,
              kind: MediaKind.video,
              platform: platform,
            ),
          ],
        );
      }

      return null;
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<MediaResolveResult> _resolveCobalt(String url, String platform) async {
    String? lastError;

    for (final instance in cobaltInstances) {
      try {
        final res = await _dio.post<Map<String, dynamic>>(
          instance,
          data: {
            'url': url,
            'videoQuality': '1080',
            'filenameStyle': 'basic',
            'downloadMode': 'auto',
          },
          options: Options(
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            responseType: ResponseType.json,
            receiveTimeout: const Duration(seconds: 45),
            sendTimeout: const Duration(seconds: 20),
            validateStatus: (s) => s != null && s < 500,
          ),
        );

        final data = res.data;
        if (data == null) {
          lastError = 'Empty response from download service';
          continue;
        }

        final status = data['status']?.toString() ?? '';
        if (status == 'error') {
          final code = (data['error'] is Map)
              ? data['error']['code']?.toString()
              : data['text']?.toString();
          lastError = _friendlyCobaltError(code);
          // Auth / rate-limit → try next instance
          if (code != null &&
              (code.contains('auth') ||
                  code.contains('rate') ||
                  code.contains('jwt') ||
                  code.contains('turnstile'))) {
            continue;
          }
          // Content errors won't succeed on other instances either for same URL often,
          // but still try next instance for relay failures.
          if (code != null && code.contains('relay')) {
            continue;
          }
          continue;
        }

        if (status == 'picker') {
          final picker = data['picker'];
          if (picker is! List || picker.isEmpty) {
            lastError = 'No media found in this post';
            continue;
          }
          final titleBase = platform;
          final items = <ResolvedMedia>[];
          for (var i = 0; i < picker.length; i++) {
            final item = picker[i];
            if (item is! Map) continue;
            final map = item.cast<String, dynamic>();
            final dl = map['url']?.toString() ?? '';
            if (dl.isEmpty) continue;
            final type = map['type']?.toString();
            final thumb = map['thumb']?.toString() ?? '';
            final kind = _kindFromType(type, dl);
            final ext = kind == MediaKind.video
                ? 'mp4'
                : (kind == MediaKind.gif ? 'gif' : 'jpg');
            items.add(
              ResolvedMedia(
                sourceUrl: url,
                downloadUrl: dl,
                title: '$titleBase media ${i + 1}',
                thumbnailUrl: thumb,
                filename: '${platform.toLowerCase().replaceAll(' ', '_')}_$i.$ext',
                kind: kind,
                platform: platform,
              ),
            );
          }
          if (items.isNotEmpty) return MediaResolveResult(items: items);
          lastError = 'No downloadable media in picker';
          continue;
        }

        if (status == 'tunnel' || status == 'redirect') {
          final dl = data['url']?.toString() ?? '';
          if (dl.isEmpty) {
            lastError = 'Download URL missing';
            continue;
          }
          final filename = data['filename']?.toString() ??
              'media_${DateTime.now().millisecondsSinceEpoch}.mp4';
          final kind = _kindFromPath(filename.toLowerCase());
          final title = filename.contains('.')
              ? filename.substring(0, filename.lastIndexOf('.'))
              : filename;
          return MediaResolveResult(
            items: [
              ResolvedMedia(
                sourceUrl: url,
                downloadUrl: dl,
                title: title.replaceAll('_', ' '),
                thumbnailUrl: kind == MediaKind.image || kind == MediaKind.gif ? dl : '',
                filename: filename,
                kind: kind,
                platform: platform,
              ),
            ],
          );
        }

        // local-processing: use first tunnel URL if present
        if (status == 'local-processing') {
          final tunnels = data['tunnel'];
          if (tunnels is List && tunnels.isNotEmpty) {
            final dl = tunnels.first.toString();
            final output = data['output'];
            final filename = (output is Map ? output['filename'] : null)?.toString() ??
                'media_${DateTime.now().millisecondsSinceEpoch}.mp4';
            final kind = _kindFromPath(filename.toLowerCase());
            return MediaResolveResult(
              items: [
                ResolvedMedia(
                  sourceUrl: url,
                  downloadUrl: dl,
                  title: filename,
                  thumbnailUrl: '',
                  filename: filename,
                  kind: kind,
                  platform: platform,
                ),
              ],
            );
          }
        }

        lastError = 'Unexpected response from download service';
      } on DioException catch (e) {
        lastError = e.message ?? 'Network error';
        continue;
      } catch (_) {
        lastError = 'Failed to reach download service';
        continue;
      }
    }

    return MediaResolveResult(
      items: [],
      error: lastError ?? 'All download services failed',
    );
  }

  String _friendlyCobaltError(String? code) {
    if (code == null || code.isEmpty) return 'Failed to fetch media';
    if (code.contains('link.unsupported') || code.contains('service')) {
      return 'This link or platform is not supported';
    }
    if (code.contains('content.video.live')) {
      return 'Live streams cannot be downloaded';
    }
    if (code.contains('content.post.unavailable') ||
        code.contains('content.video.unavailable')) {
      return 'Post is private, deleted, or unavailable';
    }
    if (code.contains('auth')) {
      return 'Download service requires authentication — try again later';
    }
    if (code.contains('rate')) {
      return 'Too many requests — please wait a moment';
    }
    if (code.contains('relay')) {
      return 'Download service temporarily unavailable — try again';
    }
    return 'Failed to fetch media ($code)';
  }
}
