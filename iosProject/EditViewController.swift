//
//  ViewController.swift
//  iosProject
//
//  Created by 지훈 on 5/31/25.
//
import UIKit
import NMapsMap
import CoreLocation

class EditViewController: UIViewController, CLLocationManagerDelegate, NMFMapViewTouchDelegate {
    var currentMarker: NMFMarker?
    var mapView: NMFMapView?
    let locationManager = CLLocationManager()

    @IBAction func GotoMemo(_ sender: Any) {
    }
    @IBOutlet weak var mapContainerView: UIView!
    @IBOutlet weak var locationTitleLabel: UILabel!
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var locationSubtitleLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        if let info = Bundle.main.infoDictionary {
              print("🧾 Client ID: \(info["NAVER_CLIENT_ID"] ?? "없음")")
              print("🧾 Client Secret: \(info["NAVER_CLIENT_SECRET"] ?? "없음")")
          }

        mapContainerView.layoutIfNeeded()
        setupMap()
        setupLocationManager()
        setupLongPressGesture() // ✅ 추가
        print("🧭 mapContainerView.bounds: \(mapContainerView.bounds)")

        DispatchQueue.global().async {
            if CLLocationManager.locationServicesEnabled() {
                if #available(iOS 14.0, *) {
                    let status = self.locationManager.authorizationStatus
                    if status == .authorizedWhenInUse || status == .authorizedAlways {
                        self.locationManager.startUpdatingLocation()
                    }
                } else {
                    let status = CLLocationManager.authorizationStatus()
                    if status == .authorizedWhenInUse || status == .authorizedAlways {
                        self.locationManager.startUpdatingLocation()
                    }
                }
            }
        }
    }
    private func setupLongPressGesture() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        mapView?.addGestureRecognizer(longPress)
    }
    @objc private func handleLongPress(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        
        guard let mapView = self.mapView else { return }
        let point = sender.location(in: mapView)
        let latlng = mapView.projection.latlng(from: point)

        addMarker(at: latlng, caption: "선택한 위치")
        locationTitleLabel.text = "주소 불러오는 중..."
        locationSubtitleLabel.text = ""

        fetchAddress(from: latlng) { address in
            let parts = (address ?? "주소 없음|").components(separatedBy: "|")
            self.locationTitleLabel.text = parts.first ?? "주소 없음"
            self.locationSubtitleLabel.text = parts.count > 1 ? parts[1] : ""
        }


    }

    private func fetchApiKeys() -> (clientId: String?, clientSecret: String?) {
        guard let infoDict = Bundle.main.infoDictionary else { return (nil, nil) }
        let clientId = infoDict["NAVER_CLIENT_ID"] as? String
        let clientSecret = infoDict["NAVER_CLIENT_SECRET"] as? String
        return (clientId, clientSecret)
    }

    private func setupMap() {
        let map = NMFMapView(frame: mapContainerView.bounds)
        map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        map.touchDelegate = self
        mapContainerView.addSubview(map)
        self.mapView = map
        print("✅ touchDelegate 및 지도 설정 완료")
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if #available(iOS 14.0, *) {
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                locationManager.startUpdatingLocation()
            }
        } else {
            if CLLocationManager.authorizationStatus() == .authorizedWhenInUse || CLLocationManager.authorizationStatus() == .authorizedAlways {
                locationManager.startUpdatingLocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let lat = location.coordinate.latitude
        let lng = location.coordinate.longitude
        let coord = NMGLatLng(lat: lat, lng: lng)

        let cameraUpdate = NMFCameraUpdate(scrollTo: coord)
        cameraUpdate.animation = .easeIn
        mapView?.moveCamera(cameraUpdate)

        addMarker(at: coord, caption: "현재 위치")
        locationSubtitleLabel.text = ""
        locationTitleLabel.text = "주소 불러오는 중..."
        fetchAddress(from: coord) { address in
            let parts = (address ?? "주소 없음|").components(separatedBy: "|")
            self.locationTitleLabel.text = parts.first ?? "주소 없음"
            self.locationSubtitleLabel.text = parts.count > 1 ? parts[1] : ""
        }


        locationManager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ 위치 가져오기 실패: \(error.localizedDescription)")
    }

    private func addMarker(at coord: NMGLatLng, caption: String) {
        currentMarker?.mapView = nil
        let marker = NMFMarker()
        marker.position = coord
        marker.captionText = caption
        marker.captionColor = .systemBlue
        marker.captionTextSize = 14
        marker.iconImage = NMF_MARKER_IMAGE_GREEN
        marker.width = 30
        marker.height = 40
        marker.anchor = CGPoint(x: 0.5, y: 1)
        marker.mapView = mapView
        currentMarker = marker
    }
    override func viewDidLayoutSubviews() {
           super.viewDidLayoutSubviews()

           // mapView가 아직 생성되지 않았으면 다시 설정
           if mapView == nil {
               setupMap()
           }
       }
    
    private func fetchAddress(from latlng: NMGLatLng, completion: @escaping (String?) -> Void) {
        let (clientId, clientSecret) = fetchApiKeys()

        
           guard let clientId = clientId, let clientSecret = clientSecret else {
               print("❌ API 키 누락")
               completion(nil)
               return
           }

           let coords = "\(latlng.lng),\(latlng.lat)"
           var urlComponents = URLComponents(string: "https://maps.apigw.ntruss.com/map-reversegeocode/v2/gc")!
           urlComponents.queryItems = [
               URLQueryItem(name: "coords", value: coords),
               URLQueryItem(name: "orders", value: "roadaddr"),
               URLQueryItem(name: "output", value: "json")
           ]
           
           var request = URLRequest(url: urlComponents.url!)
           request.setValue(clientId, forHTTPHeaderField: "X-NCP-APIGW-API-KEY-ID")
           request.setValue(clientSecret, forHTTPHeaderField: "X-NCP-APIGW-API-KEY")

        
   


        // ✅ URLSession으로 실제 요청 보내고 응답 처리
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ 네트워크 에러: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            do {
                // ✅ 에러 응답 먼저 확인
                if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = jsonObject["error"] as? [String: Any] {
                    print("❗️API 오류: \(error["message"] ?? "")")
                    DispatchQueue.main.async {
                        completion("주소 없음|") // 에러일 경우 기본값
                    }


                    return
                }

                // ✅ 정상 디코딩
                let decoded = try JSONDecoder().decode(ReverseGeocodingModel.self, from: data)
                if let first = decoded.results.first {
                    let region = first.region
                    let land = first.land
                    let roadName = land?.name ?? ""
                    let number1 = land?.number1 ?? ""
                    let number2 = land?.number2 ?? ""
                    let buildingName = (land?.addition0?.type == "building") ? (land?.addition0?.value ?? "") : ""

                    let fullAddress = "\(region.area1.name) \(region.area2?.name ?? "") \(region.area3?.name ?? "") \(roadName) \(number1)\(number2)"
                    let addressWithBuilding = "\(fullAddress)|\(buildingName)"
                    print("📍 상세 주소: \(addressWithBuilding)")
                    DispatchQueue.main.async { completion(addressWithBuilding) }

                } else {
                    DispatchQueue.main.async { completion(nil) }
                }
            } catch {
                print("❌ 디코딩 실패: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }


    
}

// MARK: - 사용자 클릭으로 마커 추가
extension EditViewController {
    func mapView(_ mapView: NMFMapView, didLongTapMap latlng: NMGLatLng) {
        print("🟢 지도 탭됨 at \(latlng.lat), \(latlng.lng)")
        addMarker(at: latlng, caption: "여기예요!")
        
        // 주소 초기화
        locationTitleLabel.text = "주소 불러오는 중..."
        locationSubtitleLabel.text = ""  // 좌표 대신 비워둠
        
        fetchAddress(from: latlng) { address in
            print("📦 주소 응답: \(address ?? "주소 없음|")")
            let parts = (address ?? "주소 없음|").components(separatedBy: "|")
            self.locationTitleLabel.text = parts.first ?? "주소 없음"
            self.locationSubtitleLabel.text = parts.count > 1 ? parts[1] : ""
        }
    }

    // 기존 탭 이벤트 유지 (선택사항: 원하지 않으면 제거해도 됩니다)
    func mapView(_ mapView: NMFMapView, didTap latlng: NMGLatLng) {
        print("🟢 지도 탭됨 at \(latlng.lat), \(latlng.lng)")
        addMarker(at: latlng, caption: "여기예요!")
        
        // 주소 초기화
        locationTitleLabel.text = "주소 불러오는 중..."
        locationSubtitleLabel.text = ""  // 좌표 대신 비워둠
        
        fetchAddress(from: latlng) { address in
            print("📦 주소 응답: \(address ?? "주소 없음|")")
            let parts = (address ?? "주소 없음|").components(separatedBy: "|")
            self.locationTitleLabel.text = parts.first ?? "주소 없음"
            self.locationSubtitleLabel.text = parts.count > 1 ? parts[1] : ""
        }

    }

}
struct ReverseGeocodingModel: Decodable {
    let results: [Address]
}

struct Address: Decodable {
    let region: Region
    let land: Land?
}

struct Region: Decodable {
    let area1: Area1
    let area2, area3, area4: Area?
}

struct Area1: Decodable {
    let name: String
    let alias: String?
}

struct Area: Decodable {
    let name: String
}

struct Land: Decodable {
    let number1, number2: String?
    let addition0: Addition0?
    let name: String?
}

struct Addition0: Decodable {
    let type, value: String
}
