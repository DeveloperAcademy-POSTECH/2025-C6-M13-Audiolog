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
        Date.formatter.locale = Locale(identifier: "ko_KR")
        Date.formatter.amSymbol = "오전"
        Date.formatter.pmSymbol = "오후"
        Date.formatter.dateFormat = format
        return Date.formatter.string(from: self)
    }
}
