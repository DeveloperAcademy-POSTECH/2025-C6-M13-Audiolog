//
//  WeatherManager.swift
//  Audiolog
//
//  Created by Seungeun Park on 11/10/25.
//

import WeatherKit
import CoreLocation

class WeatherManager {
    private var weatherkit: Weather?
    
    func getWeather(location: CLLocation) async throws -> Weather {
        do {
            let weather = try await WeatherService.shared.weather(for: location)
            return weather
        } catch {
            throw error
        }
    }
    
}
