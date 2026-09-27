import 'package:pocketbase/pocketbase.dart';

class PocketBaseService {
  // 127.0.0.1 is the local loopback address for Windows desktop testing.
  static final pb = PocketBase('http://127.0.0.1:8090');
}
