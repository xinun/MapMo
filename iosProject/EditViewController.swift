import UIKit
import NMapsMap
import CoreLocation

// MARK: - LocationInfo Data Model
struct LocationInfo {
    let title: String
    let subtitle: String?
}

// MARK: - EditViewController
class EditViewController: UIViewController, CLLocationManagerDelegate, UIGestureRecognizerDelegate {

    // MARK: - Properties
    private var mapView: NMFMapView!
    private let locationManager = CLLocationManager()
    private var currentMarker: NMFMarker?
    private var selectedLocationInfo: LocationInfo?
    private var selectedCoordinates: NMGLatLng? // 👈 1. 선택된 좌표를 저장할 변수 추가

    @objc private func mapContainerTapped() {
        print("🔴🔴🔴 mapContainerView가 탭 되었습니다! (자체 제스처) 🔴🔴🔴")
    }
    // MARK: - IBOutlets
    @IBOutlet weak var mapContainerView: UIView!
    @IBOutlet weak var locationTitleLabel: UILabel!
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var locationSubtitleLabel: UILabel!

    // MARK: - IBActions
    @IBAction func GotoMemo(_ sender: Any) {
        guard selectedLocationInfo != nil else {
            let alert = UIAlertController(title: "알림", message: "일기를 작성할 위치를 먼저 선택해주세요.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default))
            present(alert, animated: true)
            return
        }
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocationManager()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if mapView == nil {
            setupMap()
        }
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goToEdit2" {
            if let destinationVC = segue.destination as? EditViewController2 {
                // TODO: EditViewController2에 var locationInfo: LocationInfo? 변수 추가 후 주석 해제
                
                destinationVC.locationInfo = self.selectedLocationInfo
                destinationVC.coordinates = self.selectedCoordinates

            }
        }
    }



    private func setupMap() {
        mapView = NMFMapView(frame: mapContainerView.bounds)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.isUserInteractionEnabled = true
        mapContainerView.addSubview(mapView)

        // --- 롱탭(길게 누르기) 제스처 추가 ---
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        mapContainerView.addGestureRecognizer(longPressGesture)
        
        // --- 탭(짧게 누르기) 제스처 추가 ---
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGesture.delegate = self // 💡 이 줄을 추가해주세요.

        mapContainerView.addGestureRecognizer(tapGesture)
        
        // 💡 중요: 지도 자체의 더블탭 제스처와의 충돌을 해결합니다.
        // 우리가 만든 '싱글탭'이, 지도의 '더블탭'이 확실히 아닐 때만 실행되도록 설정합니다.
        if let doubleTapGesture = mapView.gestureRecognizers?.first(where: {
            ($0 as? UITapGestureRecognizer)?.numberOfTapsRequired == 2
        }) {
            tapGesture.require(toFail: doubleTapGesture)
            print("✅ 맵의 더블탭 제스처와 충돌 문제를 해결했습니다.")
        }
    }
    // EditViewController.swift 파일
    // EditViewController.swift 파일
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 우리가 만든 제스처와 다른 제스처(지도의 제스처)가 동시에 인식되도록 허용하여
        // 이벤트가 중간에 소모되는 것을 방지합니다.
        return true
    }
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        // 1. mapContainerView에서 터치된 위치(CGPoint)를 가져옵니다.
        let touchPoint = gesture.location(in: mapContainerView)
        
        // 2. 터치된 화면 좌표(CGPoint)를 실제 지도의 위경도(NMGLatLng)로 변환합니다.
        let coord = mapView.projection.latlng(from: touchPoint)
        
        print("✅ 탭 발생! 좌표: \(coord.lat), \(coord.lng)")
        
        // 3. 기존에 만들어두신 위치 정보 업데이트 함수를 호출합니다.
        updateLocationDetails(for: coord, caption: "선택한 위치")
    }
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        // 제스처가 시작되는 시점에 한 번만 코드를 실행합니다.
        if gesture.state == .began {
            // 1. mapContainerView에서 터치된 위치(CGPoint)를 가져옵니다.
            let touchPoint = gesture.location(in: mapContainerView)
            
            // 2. 터치된 화면 좌표(CGPoint)를 실제 지도의 위경도(NMGLatLng)로 변환합니다.
            let coord = mapView.projection.latlng(from: touchPoint)
            
            print("✅ 롱탭 발생! 좌표: \(coord.lat), \(coord.lng)")
            
            // 3. 기존에 만들어두신 위치 정보 업데이트 함수를 호출합니다.
            updateLocationDetails(for: coord, caption: "선택한 위치")
        }
    }
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        checkLocationAuthorization()
    }
    // ✅ 이 함수 전체를 setupLocationManager() 아래에 붙여넣으세요.
    private func checkLocationAuthorization() {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = locationManager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ 위치 권한 허용됨. 위치 업데이트를 시작합니다.")
            locationManager.startUpdatingLocation()
            
        case .denied, .restricted:
            print("❌ 위치 권한 거부됨.")
            showRequestLocationServiceAlert()
            
        case .notDetermined:
            print("ℹ️ 위치 권한을 요청합니다.")
            locationManager.requestWhenInUseAuthorization()
            
        @unknown default:
            break
        }
    }
    // MARK: - Logic
    // EditViewController.swift 파일

    private func updateLocationDetails(for latlng: NMGLatLng, caption: String) {
        self.selectedCoordinates = latlng

        addMarker(at: latlng, caption: caption)
        
        // UI 초기화
        locationTitleLabel.text = "위치 정보 탐색 중..."
        locationSubtitleLabel.text = ""
        
        // 1. 주소 API 호출
        fetchAddress(from: latlng) { [weak self] address in
            guard let self = self else { return }
            
            let parts = (address ?? "주소 없음|").components(separatedBy: "|")
            let addressText = parts.first ?? "주소 없음"
            let buildingNameInAddress = parts.count > 1 ? parts[1] : ""
            
            // 2. 장소(상호명) API 호출
            self.fetchPlaceName(from: latlng) { placeName in
                DispatchQueue.main.async {
                    // 3. 결과에 따라 UI 업데이트
                    if let place = placeName, !place.isEmpty {
                        // 성공: 상호명이 있을 경우 (가장 이상적인 케이스)
                        self.locationTitleLabel.text = place
                        self.locationSubtitleLabel.text = addressText
                        self.selectedLocationInfo = LocationInfo(title: place, subtitle: addressText)
                        
                    } else if !buildingNameInAddress.isEmpty {
                        // 차선책: 상호명은 없지만 주소 API에서 건물명을 받았을 경우
                        self.locationTitleLabel.text = buildingNameInAddress
                        self.locationSubtitleLabel.text = addressText
                        self.selectedLocationInfo = LocationInfo(title: buildingNameInAddress, subtitle: addressText)
                        
                    } else {
                        // 최후의 수단: 상호명, 건물명 모두 없고 주소만 있을 경우
                        self.locationTitleLabel.text = addressText
                        self.locationSubtitleLabel.text = "" // 부제목은 비움
                        self.selectedLocationInfo = LocationInfo(title: addressText, subtitle: nil)
                    }
                }
            }
        }
    }

    private func addMarker(at coord: NMGLatLng, caption: String) {
        currentMarker?.mapView = nil
        let marker = NMFMarker(position: coord)
        marker.captionText = caption
        if let image = UIImage(named: "mint_marker_icon") {
                marker.iconImage = NMFOverlayImage(image: image)
                marker.width = 45
                marker.height = 45
            }

        marker.mapView = mapView
        currentMarker = marker
    }
}



// MARK: - API Calls & Models
extension EditViewController {
    private func fetchApiKeys() -> (clientId: String?, clientSecret: String?) {
        guard let infoDict = Bundle.main.infoDictionary else { return (nil, nil) }
        let clientId = infoDict["NAVER_CLIENT_ID"] as? String
        let clientSecret = infoDict["NAVER_CLIENT_SECRET"] as? String
        return (clientId, clientSecret)
    }
    
    private func fetchAddress(from latlng: NMGLatLng, completion: @escaping (String?) -> Void) {
        let (clientId, clientSecret) = fetchApiKeys()
        guard let clientId = clientId, let clientSecret = clientSecret else {
            completion(nil); return
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

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = jsonObject["error"] as? [String: Any] {
                    print("❗️ 주소 API 오류: \(error["message"] ?? "")")
                    DispatchQueue.main.async { completion("주소 없음|") }
                    return
                }
                
                let decoded = try JSONDecoder().decode(ReverseGeocodingModel.self, from: data)
                if let first = decoded.results.first {
                    let region = first.region
                    let land = first.land
                    let buildingName = (land?.addition0?.type == "building") ? (land?.addition0?.value ?? "") : ""
                    let fullAddress = "\(region.area1.name) \(region.area2?.name ?? "") \(region.area3?.name ?? "") \(land?.name ?? "") \(land?.number1 ?? "")\(land?.number2 ?? "")".trimmingCharacters(in: .whitespaces)
                    let addressWithBuilding = "\(fullAddress)|\(buildingName)"
                    DispatchQueue.main.async { completion(addressWithBuilding) }
                } else {
                    DispatchQueue.main.async { completion(nil) }
                }
            } catch {
                print("❌ 주소 디코딩 실패: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }

    private func fetchPlaceName(from latlng: NMGLatLng, completion: @escaping (String?) -> Void) {
        let (clientId, clientSecret) = fetchApiKeys()
        guard let clientId = clientId, let clientSecret = clientSecret else {
            completion(nil); return
        }

        var components = URLComponents(string: "https://openapi.naver.com/v1/search/local.json")!
        components.queryItems = [
            URLQueryItem(name: "query", value: ""),
            URLQueryItem(name: "display", value: "1"),
            URLQueryItem(name: "sort", value: "random"),
            URLQueryItem(name: "coordinate", value: "\(latlng.lng),\(latlng.lat)")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(clientId, forHTTPHeaderField: "X-Naver-Client-Id")
        request.setValue(clientSecret, forHTTPHeaderField: "X-Naver-Client-Secret")

        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data = data, error == nil else {
                completion(nil); return
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let items = json["items"] as? [[String: Any]],
               let first = items.first,
               let titleHTML = first["title"] as? String {
                let title = titleHTML.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
                completion(title)
            } else {
                completion(nil)
            }
        }.resume()
    }
}

// MARK: - Delegate Conformance
extension EditViewController {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        // 위치 권한 상태가 변경될 때마다 이 함수가 호출됩니다.
        checkLocationAuthorization()
    }

    func showRequestLocationServiceAlert() {
      let requestLocationServiceAlert = UIAlertController(title: "위치 정보 이용", message: "위치 서비스를 사용할 수 없습니다.\n디바이스의 '설정'에서 위치 서비스를 켜주세요.", preferredStyle: .alert)
      let goSetting = UIAlertAction(title: "설정으로 이동", style: .default) { _ in
        if let appSetting = URL(string: UIApplication.openSettingsURLString){
          UIApplication.shared.open(appSetting)
        }
      }
      let cancel = UIAlertAction(title: "취소", style: .cancel)
      requestLocationServiceAlert.addAction(cancel)
      requestLocationServiceAlert.addAction(goSetting)
      
      present(requestLocationServiceAlert, animated: true, completion: nil)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        locationManager.stopUpdatingLocation()
        
        let coord = NMGLatLng(lat: location.coordinate.latitude, lng: location.coordinate.longitude)
        mapView?.moveCamera(NMFCameraUpdate(scrollTo: coord))
         updateLocationDetails(for: coord, caption: "현재 위치") // 최초 위치에서는 마커 표시 안 함
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ 위치 가져오기 실패: \(error.localizedDescription)")
    }
}
// MARK: - Data Models
struct ReverseGeocodingModel: Decodable { let results: [Address] }
struct Address: Decodable { let region: Region; let land: Land? }
struct Region: Decodable { let area1: Area1; let area2, area3, area4: Area? }
struct Area1: Decodable { let name: String; let alias: String? }
struct Area: Decodable { let name: String }
struct Land: Decodable { let number1, number2: String?; let addition0: Addition0?; let name: String? }
struct Addition0: Decodable { let type, value: String }
