import Flutter
import MapKit

/// Apple 地圖地點搜尋：店名、地標、地址都可，附近優先（約 50 km 範圍偏好，不排除遠處）。
/// 回傳 [{name, lat, lon}]，最多 8 筆；失敗回傳空陣列。
public class QmPlacesPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "qm/places", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(QmPlacesPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "search", let args = call.arguments as? [String: Any], let q = args["q"] as? String else {
      result(FlutterMethodNotImplemented)
      return
    }
    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = q
    if let lat = args["lat"] as? Double, let lon = args["lon"] as? Double {
      request.region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
        latitudinalMeters: 50_000, longitudinalMeters: 50_000)
    }
    MKLocalSearch(request: request).start { response, _ in
      var out: [[String: Any]] = []
      for item in (response?.mapItems ?? []).prefix(8) {
        let c = item.placemark.coordinate
        var name = item.name ?? q
        if let addr = item.placemark.title, !addr.isEmpty, addr != name { name += "・" + addr }
        out.append(["name": name, "lat": c.latitude, "lon": c.longitude])
      }
      DispatchQueue.main.async { result(out) }
    }
  }
}
