//
//  AudioProcessor.swift
//  Audiolog
//
//  Created by 성현 on 11/6/25.
//

@preconcurrency import AVFoundation
import FoundationModels

@MainActor
@Observable
final class RecordingSearcher {
    var isLanguageModelAvailable: Bool = true

    init() {}

    func configureLanguageModelSession() async {
        guard isLanguageModelAvailable else { return }

        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            isLanguageModelAvailable = true
            logger.log("[RecordingSearcher] Language model is available.")
        default:
            isLanguageModelAvailable = false
            logger.log("[RecordingSearcher] Language model is not available.")
            return
        }
    }
    
    func compare(
        searchText: String,
        recording: Recording,
        threshold: Float = 0.7
    ) async -> Bool {
        let loweredSearch = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).lowercased()
        if !loweredSearch.isEmpty {
            let titleMatch = recording.title.lowercased().contains(
                loweredSearch
            )
            let dialogMatch =
                recording.dialog?.lowercased().contains(loweredSearch) ?? false
            if titleMatch || dialogMatch {
                logger.log(
                    "[RecordingSearcher] Matched locally (title/dialog). Title: \(recording.title)"
                )
                return true
            }
            
            let prefixLength = min(2, loweredSearch.count)
            if let tags = recording.tags, prefixLength > 0 {
                let prefix = String(loweredSearch.prefix(prefixLength))
                let tagsString = tags.joined(separator: ", ")
                let tagsMatch = tagsString.contains(prefix)
                
                if tagsMatch { return true }
            }
        }

        let languageModelSession = LanguageModelSession(
            instructions: """
                유저의 검색어와 음성일기의 메타데이터를 비교해 비슷한 정도를 0.0 ~ 1.0 사이의 소수로 출력한다.

                출력형식:
                 - 예시: 0.0, 0.8, 1.0
                 - 이유는 설명하지 않는다.
                 - 소수외의 다른 메시지는 출력하지 않는다.
                """
        )

        var prompt = ""

        prompt += "유저 검색어: \(searchText) \n \n"

        prompt += "음성일기 메타데이터: [ \n"
        prompt += "제목: \(recording.title)"

        if let dialog = recording.dialog {
            prompt += "대화 내용: \(dialog) \n"
        }

        if let bgmTitle = recording.bgmTitle,
            let bgmArtist = recording.bgmArtist
        {
            prompt += "감지된 노래: \(bgmTitle) - \(bgmArtist) \n"
        }

        if let location = recording.location {
            prompt += "위치: \(location) \n"
        }

        prompt += "생성일자: \(recording.createdAt) \n"

        if let weather = recording.weather {
            prompt += "날씨: \(weather) \n"
        }
        
        if let tags = recording.tags {
            prompt += "태그: \(tags.joined(separator: ", "))"
        }

        do {
            let response = try await languageModelSession.respond(to: prompt)
            let trimmed = response.content.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            guard let score = Float(trimmed) else {
                logger.log(
                    "[RecordingSearcher] Invalid score format: \(trimmed)"
                )
                return false
            }
            logger.log(
                "[RecordingSearcher] Score: \(score), Title: \(recording.title)"
            )
            return score >= threshold
        } catch {
            logger.log("[RecordingSearcher] Scoring failed: \(error)")
            return false
        }
    }
}
