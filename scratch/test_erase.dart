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

  final tables = ['sales', 'reservations', 'stone_inventory', 'material_audits', 'customers', 'materials'];
  for (final t in tables) {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/database/records/$t?id=not.is.null'),
      headers: headers,
    );
    print('DELETE $t: status=${res.statusCode}, body=${res.body}');
  }

  print('\n--- Checking remaining records ---');
  for (final t in tables) {
    final res = await http.get(
      Uri.parse('$baseUrl/api/database/records/$t'),
      headers: headers,
    );
    print('GET $t: status=${res.statusCode}, body=${res.body}');
  }
}
