// lib/src/services/report_downloader.dart

export 'report_downloader_stub.dart'
    if (dart.library.io) 'report_downloader_io.dart'
    if (dart.library.html) 'report_downloader_web.dart';