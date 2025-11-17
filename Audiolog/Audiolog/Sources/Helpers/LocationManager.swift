//
//  LocationManager.swift
//  Audiolog
//
//  Created by Seungeun Park on 11/10/25.
//

import CoreLocation
import Foundation

class LocationManager: NSObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()

    var onLocationUpdate: ((CLLocation, String) -> Void)?
    var onError: ((String) -> Void)?

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

    func fetchBuildingNameFromKakao(
        latitude: Double,
        longitude: Double,
        location: CLLocation,
        completion: @escaping (String?) -> Void
    ) {
        guard
            let apiKey = Bundle.main.object(
                forInfoDictionaryKey: "KAKAO_REST_API_KEY"
            ) as? String
        else {
            self.fetchAddressFromCoreLocation(location) { fallback in
                completion(fallback)
            }
            return
        }

        let coordURL =
            "https://dapi.kakao.com/v2/local/geo/coord2address.json?x=\(longitude)&y=\(latitude)&input_coord=WGS84"
        guard let url = URL(string: coordURL) else {
            self.fetchAddressFromCoreLocation(location) { fallback in
                completion(fallback)
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(
            "KakaoAK \(apiKey)",
            forHTTPHeaderField: "Authorization"
        )

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                self.fetchAddressFromCoreLocation(location) { fallback in
                    completion(fallback)
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data)
                    as? [String: Any],
                    let documents = json["documents"] as? [[String: Any]]
                {
                    // road_address.building_name 사용
                    if let roadAddress = documents.first?["road_address"]
                        as? [String: Any]
                    {
                        let roadAddr =
                            roadAddress["address_name"] as? String ?? ""
                        let buildingName =
                            roadAddress["building_name"] as? String ?? ""

                        let fullAddress =
                            buildingName.isEmpty
                            ? roadAddr : "\(roadAddr) \(buildingName)"
                        completion(fullAddress)
                        return
                    }
                }
                self.fetchKeywordSearch(
                    latitude: latitude,
                    longitude: longitude,
                    location: location,
                    apiKey: apiKey,
                    completion: completion
                )
            } catch {
                self.fetchKeywordSearch(
                    latitude: latitude,
                    longitude: longitude,
                    location: location,
                    apiKey: apiKey,
                    completion: completion
                )
            }
        }.resume()
    }

    private func fetchKeywordSearch(
        latitude: Double,
        longitude: Double,
        location: CLLocation,
        apiKey: String,
        completion: @escaping (String?) -> Void
    ) {
        let keywordURL =
            "https://dapi.kakao.com/v2/local/search/keyword.json?y=\(latitude)&x=\(longitude)&radius=50"
        guard let url = URL(string: keywordURL) else {
            self.fetchAddressFromCoreLocation(location) { fallback in
                completion(fallback)
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue(
            "KakaoAK \(apiKey)",
            forHTTPHeaderField: "Authorization"
        )

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                self.fetchAddressFromCoreLocation(location) { fallback in
                    completion(fallback)
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data)
                    as? [String: Any],
                    let documents = json["documents"] as? [[String: Any]],
                    let placeName = documents.first?["place_name"] as? String
                {
                    completion(placeName)
                    return
                }
                self.fetchAddressFromCoreLocation(location) { fallback in
                    completion(fallback)
                }
            } catch {
                self.fetchAddressFromCoreLocation(location) { fallback in
                    completion(fallback)
                }
            }
        }.resume()
    }

    private func fetchAddressFromCoreLocation(
        _ location: CLLocation,
        completion: @escaping (String) -> Void
    ) {
        let geocoder = CLGeocoder()
        let locale = Locale(identifier: "ko_KR")

        geocoder.reverseGeocodeLocation(location, preferredLocale: locale) {
            placemarks,
            error in
            guard error == nil, let place = placemarks?.first else {
                self.onError?(
                    "주소 변환 실패 \(error)"
                )
                return
            }

            var address = ""

            if let locality = place.locality {
                address += locality + " "
            }

            var landmarks: [String] = []

            if let name = place.name {
                landmarks.append(name)
            }
            if let pois = place.areasOfInterest {
                landmarks.append(contentsOf: pois)
            }

            let fullAddress =
                address
                + (landmarks.isEmpty ? "" : landmarks.joined(separator: ", "))

            self.onLocationUpdate?(location, fullAddress)
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.first else { return }
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude

        fetchBuildingNameFromKakao(
            latitude: latitude,
            longitude: longitude,
            location: location
        ) {
            [weak self] buildingName in
            guard let self = self else { return }
            if let name = buildingName {
                DispatchQueue.main.async {
                    self.onLocationUpdate?(location, name)
                }
            } else {
                self.onError?("카카오맵 건물명 가져오기 실패")
            }
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        onError?("위치 가져오기 실패")
    }
}
