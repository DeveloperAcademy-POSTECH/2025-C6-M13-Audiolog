//
//  LocationManager.swift
//  Audiolog
//
//  Created by Seungeun Park on 11/10/25.
//

import Foundation
import CoreLocation

class LocationManager: NSObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()

    var onLocationUpdate: ((CLLocation, String) -> Void)?
    var onError: ((String) -> Void)?

    private var geocoder = CLGeocoder()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
            let status = locationManager.authorizationStatus
            switch status {
            case .notDetermined:
                locationManager.requestWhenInUseAuthorization()
            case .restricted, .denied:
                onError?("위치 권한 거부됨")
            case .authorizedWhenInUse, .authorizedAlways:
                locationManager.requestLocation()
            @unknown default:
                onError?("알 수 없는 에러")
            }
        }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }

        let locale = Locale(identifier: "ko-KR")
        geocoder.reverseGeocodeLocation(location, preferredLocale: locale) { placemarks, error in
            guard error == nil, let place = placemarks?.first else {
                self.onError?("주소 변환 실패: \(error?.localizedDescription ?? "알 수 없음")")
                return
            }

            var address = ""

            if let administrativeArea = place.administrativeArea {
                address += " " + administrativeArea
            }

            if let locality = place.locality {
                address += " " + locality
            }

            if let subLocality = place.subLocality {
                address += subLocality
            }

            var landmarks: [String] = []
            if let name = place.name {
                landmarks.append(name)
            }
            if let pois = place.areasOfInterest {
                landmarks.append(contentsOf: pois)
            }

            let fullAddress = address + (landmarks.isEmpty ? "" : landmarks.joined(separator: ", "))

            self.onLocationUpdate?(location, fullAddress)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onError?("위치 가져오기 실패")
        // 에러 처리 고민하기
    }
}
