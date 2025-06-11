//
//  Diary.swift
//  iosProject
//
//  Created by xinun on 6/11/25.
//

// Diary.swift

import Foundation
import FirebaseFirestore

struct Diary: Decodable, Identifiable {
    @DocumentID var id: String?
    let title: String
    let content: String
    let tags: [String]
    let createdAt: Timestamp
    
    // 위치 정보 필드 (오래된 데이터에는 없을 수 있으므로 옵셔널 '?' 처리)
    let locationTitle: String?
    let locationSubtitle: String?
    let geoPoint: GeoPoint?
    
    // 화면 표시용 날짜 포맷팅
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy. MM. dd"
        return formatter.string(from: createdAt.dateValue())
    }
}
