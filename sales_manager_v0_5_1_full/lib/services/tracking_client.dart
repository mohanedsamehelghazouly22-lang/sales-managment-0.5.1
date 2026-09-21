import 'package:http/http.dart' as http;

/// عميل HTTP بيسجّل آخر وقت كتابة على قاعدة البيانات من هذا الجهاز،
/// عشان ما نعرضش إشعار لعملية أنت لسه عاملها بنفسك على نفس الجهاز.
class TrackingClient extends http.BaseClient {
  final http.Client _inner = http.Client();

  static DateTime lastWrite = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final path = request.url.path;
    final isWrite = request.method != 'GET' && request.method != 'HEAD';
    if (isWrite && (path.contains('/rest/v1/') || path.contains('/storage/v1/'))) {
      lastWrite = DateTime.now();
    }
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
