//
//  AISuggestionView.swift
//  Audiolog
//
//  Created by Seungeun Park on 11/17/25.
//

import SwiftUI

struct AISuggestionView: View {
    @Environment(\.openURL) var openURL
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            HStack {
                Spacer()
                Image("Intelligence")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84)
                    .opacity(0.9)
                Spacer()
            }
            .frame(height: 100)
            .padding(.top, 80)

            Text("Apple Intelligence 제안")
                .font(.title3)
                .bold()
                .padding(.leading, 38)
            HStack(alignment: .top, spacing: 20) {
                Image("AIMagicStick")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36)
                VStack(alignment: .leading) {
                    Text("AI 제목 자동 생성")
                        .padding(.bottom, 3)
                        .fontWeight(.semibold)
                    Text(
                        "AI 녹음 내용을 분석하여\n별도로 제목을 수정하지 않아도\n쉽게 알아볼 수 있어요."
                    )
                    .font(.callout)
                    .foregroundColor(.lbl2)
                }
            }
            .padding(.leading, 38)
            HStack(alignment: .top, spacing: 20) {
                Image("AISearch")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36)
                VStack(alignment: .leading) {
                    Text("AI 검색 기능")
                        .padding(.bottom, 3)
                        .fontWeight(.semibold)
                    Text(
                        "녹음 날짜, 제목을 기억하지 못해도\n관련 키워드를 검색하면 AI가 파일을\n빠르게 찾아줘요."
                    )
                    .font(.callout)
                    .foregroundColor(.lbl2)
                }
            }
            .padding(.leading, 38)
            Spacer()
        }
        .ignoresSafeArea()
        Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        } label: {
            Text("인텔리전스 켜기")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .background(.blue)
        .glassEffect()
        .foregroundStyle(.white)
        .cornerRadius(1000)
        .padding(.horizontal, 38)

        Button {
            isPresented = false
        } label: {
            Text("지금 안 함")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .glassEffect()
        .foregroundStyle(.lbl1)
        .cornerRadius(1000)
        .padding(.horizontal, 38)

        Spacer()

    }
}
