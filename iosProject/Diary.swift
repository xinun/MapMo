import FirebaseFirestore
import UIKit
import NMapsMap

struct Diary: Codable, Identifiable {
    @DocumentID var id: String?

    let userId: String
    let title: String
    let content: String
    let latitude: Double
    let longitude: Double
    let locationName: String?
    let address: String?
    let tags: [String]?
    let emotion: String?
    let createdAt: Timestamp
    let updatedAt: Timestamp?

    var monthDay: String {
        return DateFormatter.monthDayFormatter.string(from: createdAt.dateValue())
    }

    // 🔽 여기에 추가하세요
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: createdAt.dateValue())
    }

    var locationTitle: String {
        return locationName ?? title
    }

    var mapLatLng: NMGLatLng {
        return NMGLatLng(lat: latitude, lng: longitude)
    }

    var markerCaption: String {
        return locationName ?? title
    }
}
