//
//  Date+.swift
//  Colight
//
//  Created by Sean Cho on 10/10/25.
//

import Foundation

extension Date {
    private static let formatter = DateFormatter()

    func formatted(_ format: String) -> String {
        Date.formatter.locale = .current
        Date.formatter.dateFormat = format
        return Date.formatter.string(from: self)
    }
}
