import '../constants/api_constants.dart';

class ImageHelper {
  ImageHelper._();

  static String parse(dynamic value) {
    if (value == null || value is! String || value.trim().isEmpty) return '';
    
    String url = value.trim();

    // Reject invalid URLs that are just schemes or file:// URLs
    if (url == 'http://' || url == 'https://' || url == 'file://') return '';
    if (url.startsWith('file://') || url.startsWith('file:///')) return '';
    if (url == '/') return '';

    // Fix for backend returning localhost URLs
    if (url.contains('localhost') || url.contains('127.0.0.1')) {
      // Replace localhost/127.0.0.1 with the correct base URL
      String fixedUrl = url;
      final baseUrl = ApiConstants.baseUrl; 
      
      fixedUrl = fixedUrl.replaceAll(RegExp(r'http://localhost:\d+'), baseUrl);
      fixedUrl = fixedUrl.replaceAll(RegExp(r'http://127.0.0.1:\d+'), baseUrl);
      fixedUrl = fixedUrl.replaceAll('http://localhost', baseUrl);
      fixedUrl = fixedUrl.replaceAll('http://127.0.0.1', baseUrl);
      
      return fixedUrl;
    }

    if (url.startsWith('http')) return url;
    if (url.startsWith('/')) return '${ApiConstants.baseUrl}$url';
    return '${ApiConstants.baseUrl}/$url';
  }
}
