////
////  WeatherManager.swift
////  Audiolog
////
////  Created by Seungeun Park on 11/10/25.
////
//
//import WeatherKit
//import CoreLocation
//
//class WeatherManager {
//    private var weatherkit: Weather?
//
//    func getWeather(location: CLLocation) async throws -> String {
//        let weather = try await WeatherService.shared.weather(for: location)
//        let condition = weather.currentWeather.condition
//        return mapConditionToKorean(condition)
//    }
//
//    private func mapConditionToKorean(_ condition: WeatherCondition) -> String {
//        switch condition {
//        case .blowingDust: return "먼지 또는 모래바람"
//        case .clear: return "맑음"
//        case .cloudy: return "흐림"
//        case .foggy: return "안개"
//        case .haze: return "옅은 안개"
//        case .mostlyClear: return "대체로 맑음"
//        case .mostlyCloudy: return "대체로 흐림"
//        case .partlyCloudy: return "부분적으로 흐림"
//        case .smoky: return "연기"
//
//        case .breezy: return "산들바람"
//        case .windy: return "강한 바람"
//
//        case .drizzle: return "이슬비"
//        case .heavyRain: return "강한 비"
//        case .isolatedThunderstorms: return "드문 천둥번개"
//        case .rain: return "비"
//        case .sunShowers: return "맑은 날의 소나기"
//        case .scatteredThunderstorms: return "산재한 천둥번개"
//        case .strongStorms: return "강한 폭풍"
//        case .thunderstorms: return "천둥번개"
//
//        case .frigid: return "한랭"
//        case .hail: return "우박"
//        case .hot: return "더움"
//
//        case .flurries: return "눈날림"
//        case .sleet: return "진눈깨비"
//        case .snow: return "눈"
//        case .sunFlurries: return "맑은 날의 눈날림"
//        case .wintryMix: return "겨울 혼합 강수"
//
//        case .blizzard: return "눈보라"
//        case .blowingSnow: return "날리는 눈"
//        case .freezingDrizzle: return "얼어붙는 이슬비"
//        case .freezingRain: return "얼어붙는 비"
//        case .heavySnow: return "폭설"
//
//        case .hurricane: return "허리케인"
//        case .tropicalStorm: return "열대성 폭풍"
//
//        @unknown default:
//            return "알 수 없음"
//        }
//    }
//}
