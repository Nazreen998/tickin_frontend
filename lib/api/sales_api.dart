import '../api/http_client.dart';
import '../config/api_config.dart';

class SalesApi {
  final HttpClient client;
  SalesApi(this.client);

  Future<Map<String, dynamic>> home() async {
    final url = "${ApiConfig.sales}/home";
    print("SalesApi.home() URL => $url");

    final res = await client.get(url);
    // ✅ ADD THESE EXACT LINES HERE
    print("SalesApi.home() role => ${res["role"]}");
    print("SalesApi.home() distributorCount => ${res["distributorCount"]}");
    print("SalesApi.home() distributors raw => ${res["distributors"]}");

    // full response or key part
    print("SalesApi.home() response keys => ${res.keys}");
    print(
      "SalesApi.home() distributorDropdown raw => ${res["distributorDropdown"]}",
    );

    return res;
  }

  Future<List<Map<String, dynamic>>> distributorDropdown() async {
    final res = await home();

    final list = (res["distributorDropdown"] ?? []) as List;
    print("distributorDropdown() raw list length => ${list.length}");
    if (list.isNotEmpty) {
      print("distributorDropdown() first item => ${list.first}");
      print(
        "distributorDropdown() first item runtimeType => ${list.first.runtimeType}",
      );
    }

    final result = list
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();

    print("distributorDropdown() parsed result length => ${result.length}");
    if (result.isNotEmpty) {
      print("distributorDropdown() parsed first => ${result.first}");
    }

    return result;
  }

  Future<List<Map<String, dynamic>>> homeProducts() async {
    final res = await home();
    final list = (res["products"] ?? []) as List;
    return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }
}
