//
//  ViewController.swift
//  iosProject
//
//  Created by 지훈 on 5/31/25.
//
// MapViewController.swift

import UIKit
import NMapsMap
import CoreLocation
import FirebaseAuth
import FirebaseFirestore

class MapViewController: UIViewController, CLLocationManagerDelegate {
    
    @IBOutlet weak var mapView: NMFMapView!
    let locationManager = CLLocationManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.delegate = self
        checkLocationAuthorization() // ✅ 새로운 권한 확인 함수를 호출
        
        fetchAndDisplayDiaries()
    }
    // ✅ 이 함수 전체를 클래스 안에 추가해주세요.
    func checkLocationAuthorization() {
        let status: CLAuthorizationStatus
        
        if #available(iOS 14.0, *) {
            status = locationManager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            // ⭐️ 권한이 있다면, 즉시 위치 업데이트를 시작합니다.
            print("✅ 위치 권한 있음. 위치 업데이트 시작.")
            locationManager.startUpdatingLocation()
            
        case .notDetermined:
            // 아직 권한을 요청하지 않았다면, 요청합니다.
            print("ℹ️ 위치 권한을 요청합니다.")
            locationManager.requestWhenInUseAuthorization()
            
        case .denied, .restricted:
            // 권한이 거부된 상태입니다.
            print("❌ 위치 권한이 거부되었습니다.")
            // 필요하다면 설정으로 유도하는 알림창을 띄울 수 있습니다.
            
        @unknown default:
            break
        }
    }
    /// Firestore에서 모든 일기를 가져와 지도에 마커로 표시합니다.
    func fetchAndDisplayDiaries() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        db.collection("users").document(userId).collection("diaries").getDocuments { (querySnapshot, error) in
            if let error = error {
                print("❌ 데이터 로딩 실패: \(error.localizedDescription)")
                return
            }
            
            guard let documents = querySnapshot?.documents else { return }
            
            // ✅ Firestore 문서를 새로운 Diary 모델로 자동 디코딩합니다.
            let diaries = documents.compactMap { document -> Diary? in
                try? document.data(as: Diary.self)
            }
            
            // 불러온 모든 일기에 대해 마커를 생성합니다.
            for diary in diaries {
                self.createMarker(for: diary)
            }
        }
    }
    
    /// Diary 객체를 기반으로 지도에 마커를 생성하고 탭 이벤트를 설정합니다.
    func createMarker(for diary: Diary) {
        // ✅ 옵셔널인 geoPoint를 안전하게 해제합니다.
        guard let geoPoint = diary.geoPoint else { return }
        
        let marker = NMFMarker()
        marker.position = NMGLatLng(lat: geoPoint.latitude, lng: geoPoint.longitude)
        marker.captionText = diary.locationTitle ?? diary.title
        marker.mapView = self.mapView
        
        marker.touchHandler = { [weak self] (overlay) -> Bool in
            self?.showDiaryAlert(title: diary.title, message: diary.content)
            return true
        }
    }
    /// 마커를 탭했을 때 보여줄 알림(Alert) 창을 띄웁니다.
    func showDiaryAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    // MARK: - CLLocationManagerDelegate (현재 위치로 카메라 이동)
    
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
        // 앱 실행 시 한 번만 현재 위치로 카메라를 이동시킵니다.
        guard let location = locations.last else { return }
        locationManager.stopUpdatingLocation() // 위치 업데이트 중지
        
        let currentLatLng = NMGLatLng(lat: location.coordinate.latitude, lng: location.coordinate.longitude)
        
        // 1. 카메라를 현재 위치로 이동
        let cameraUpdate = NMFCameraUpdate(scrollTo: currentLatLng)
        cameraUpdate.animation = .easeIn
        mapView.moveCamera(cameraUpdate)
        
        // 2. ✅ '현재 위치'를 위한 특별한 마커를 생성하여 지도에 추가합니다.
        let currentLocationMarker = NMFMarker()
        currentLocationMarker.position = currentLatLng
        currentLocationMarker.captionText = "현재 위치"
        currentLocationMarker.iconImage = NMF_MARKER_IMAGE_BLUE
        currentLocationMarker.mapView = self.mapView
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ 위치 가져오기 실패: \(error.localizedDescription)")
    }
}
