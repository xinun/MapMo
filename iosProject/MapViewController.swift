//
//  ViewController.swift
//  iosProject
//
//  Created by 지훈 on 5/31/25.
//

import UIKit
import NMapsMap
import CoreLocation

class MapViewController: UIViewController, CLLocationManagerDelegate {
    
    var currentMarker: NMFMarker?

    @IBOutlet weak var MapView: NMFMapView!
    let locationManager = CLLocationManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        MapView.touchDelegate = self
        setupLongPressGesture()

        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()

        // ✅ 위치 서비스 확인을 메인 스레드가 아닌 백그라운드 스레드에서 실행
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
        MapView.addGestureRecognizer(longPress)
    }
    @objc private func handleLongPress(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        
        let point = sender.location(in: MapView)
        let latlng = MapView.projection.latlng(from: point)

        // 기존 마커 제거
        currentMarker?.mapView = nil

        // 새 마커 생성
        let marker = NMFMarker()
        marker.position = latlng
        marker.captionText = "선택한 위치"
        marker.captionColor = .systemGreen
        marker.iconImage = NMF_MARKER_IMAGE_GREEN
        marker.width = 30
        marker.height = 40
        marker.anchor = CGPoint(x: 0.5, y: 1)
        
        // ✅ 삭제 버튼 표시 위한 핸들러 추가
        marker.touchHandler = { [weak self] _ in
            self?.showDeleteAlert(for: marker)
            return true
        }

        marker.mapView = MapView
        currentMarker = marker
    }
    private func showDeleteAlert(for marker: NMFMarker) {
        let alert = UIAlertController(title: "마커 삭제", message: "이 마커를 삭제할까요?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "삭제", style: .destructive, handler: { _ in
            marker.mapView = nil
            if self.currentMarker === marker {
                self.currentMarker = nil
            }
        }))
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        present(alert, animated: true)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if #available(iOS 14.0, *) {
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                locationManager.startUpdatingLocation()
            case .denied, .restricted:
                print("❌ 위치 권한 거부됨")
            case .notDetermined:
                break
            @unknown default:
                break
            }
        } else {
            // iOS 13 이하용 처리
            let status = CLLocationManager.authorizationStatus()
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                locationManager.startUpdatingLocation()
            case .denied, .restricted:
                print("❌ 위치 권한 거부됨")
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let lat = location.coordinate.latitude
        let lng = location.coordinate.longitude
        let cameraUpdate = NMFCameraUpdate(scrollTo: NMGLatLng(lat: lat, lng: lng))
        cameraUpdate.animation = .easeIn
        MapView.moveCamera(cameraUpdate)

        // 마커 표시 (선택 사항)
        let marker = NMFMarker()
        marker.position = NMGLatLng(lat: lat, lng: lng)
        marker.captionText = "현재 위치"
        marker.mapView = MapView

        // 위치 업데이트 중지 (필요에 따라 계속 받을 수도 있음)
        locationManager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ 위치 가져오기 실패: \(error.localizedDescription)")
    }

}

extension MapViewController: NMFMapViewTouchDelegate {
    private func mapView(_ mapView: NMFMapView, didTap latlng: NMGLatLng) {
        print("🟢 지도 클릭됨 at \(latlng.lat), \(latlng.lng)")

        // 기존 마커 제거 (선택)
        currentMarker?.mapView = nil

        // 새 마커 생성
        let marker = NMFMarker()
        marker.position = latlng
        marker.captionText = "선택한 위치"
        marker.captionColor = .systemBlue
        marker.captionTextSize = 14
        marker.iconImage = NMF_MARKER_IMAGE_GREEN
        marker.width = 30
        marker.height = 40
        marker.anchor = CGPoint(x: 0.5, y: 1)

        marker.mapView = mapView
        currentMarker = marker
    }
}
