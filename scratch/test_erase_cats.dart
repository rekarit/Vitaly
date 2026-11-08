import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const baseUrl = 'https://ufn3ge8i.us-east.insforge.app';
  const anonKey = 'ik_e1f7df29ef2eaccacd57140130f8ac09';
  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $anonKey',
    'apikey': anonKey,
  };

  final res = await http.delete(
    Uri.parse('$baseUrl/api/database/records/categories?id=not.is.null'),
    headers: headers,
  );
  print('DELETE categories: status=${res.statusCode}, body=${res.body}');

  final getRes = await http.get(
    Uri.parse('$baseUrl/api/database/records/categories'),
    headers: headers,
  );
  print('GET categories: status=${getRes.statusCode}, body=${getRes.body}');
}
