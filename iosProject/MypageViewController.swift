import Foundation
import UIKit
import FirebaseFirestore
import FirebaseAuth

struct EmotionStats: Codable {
    var counts: [String: Int]
}

// MARK: - 날짜 포맷 확장
extension DateFormatter {
    static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

// MARK: - 뷰컨트롤러
class MypageViewController: UIViewController {
    private var recommendedEmotionDiaries: [Diary] = []
    private var todayDiaries: [Diary] = []

    private let db = Firestore.firestore()
    private var currentUserId: String? {
        return Auth.auth().currentUser?.uid
    }

    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()

    private let todayTitleLabel = SectionTitleLabel("과거의 오늘")

    private let emotionTitleLabel = SectionTitleLabel("감정별 추천")

    private let locationTitleLabel = SectionTitleLabel("방문한 장소")
    private let locationLabel = SectionContentLabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.title = "마이페이지"
        setupUI()
        //fetchData()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchData() // ✅ 화면이 나타날 때마다 데이터를 새로고침
    }
    // MARK: - UI Setup
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.spacing = 24
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)

 
        [
            todayTitleLabel, todayCollectionView,
            emotionTitleLabel, emotionCollectionView,
            locationTitleLabel, locationLabel
        ].forEach { contentStackView.addArrangedSubview($0) }

        todayCollectionView.dataSource = self
        todayCollectionView.delegate = self
        emotionCollectionView.dataSource = self     // ✅ 추가
        emotionCollectionView.delegate = self
        emotionCollectionView.heightAnchor.constraint(equalToConstant: 110).isActive = true

        todayCollectionView.heightAnchor.constraint(equalToConstant: 110).isActive = true

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    // MARK: - Data Fetch
    private func fetchData() {
        guard let userId = currentUserId else { return }
        fetchTodayDiaries(for: userId)
        fetchEmotionRecommendations(for: userId)
        fetchFrequentLocations(for: userId)
    }

    private func fetchTodayDiaries(for userId: String) {
        let monthDay = DateFormatter.monthDayFormatter.string(from: Date())

        db.collection("users").document(userId).collection("diaries")
            .whereField("monthDay", isEqualTo: monthDay)
            .getDocuments { snapshot, error in
                if let error = error {
                    self.todayDiaries = []
                    self.todayCollectionView.reloadData()
                    return
                }

                let entries = snapshot?.documents.compactMap {
                    try? $0.data(as: Diary.self)
                } ?? []

                self.todayDiaries = entries
                self.todayCollectionView.reloadData()
            }
    }

 

    private let todayCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 9
        layout.itemSize = CGSize(width: 170, height: 100)
        layout.estimatedItemSize = .zero
        layout.sectionInset = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.showsHorizontalScrollIndicator = true
        collectionView.backgroundColor = .clear
        collectionView.register(TodayDiaryCell.self, forCellWithReuseIdentifier: "TodayDiaryCell")
        return collectionView
    }()

    private func fetchEmotionRecommendations(for userId: String) {
        // 1. 사용자 감정 통계 가져오기
        db.collection("users").document(userId).collection("emotionStats").document("summary")
            .getDocument { [weak self] (documentSnapshot, error) in
                guard let self = self else { return }

                if let error = error {
                    return
                }

                guard let document = documentSnapshot, document.exists else {
                    return
                }

                do {
                    let emotionStats = try document.data(as: EmotionStats.self)
                    
                    let availableEmotions = Array(emotionStats.counts.keys) // 맵의 키들을 배열로 만듦
                    guard let selectedEmotionForRecommendation = availableEmotions.randomElement() else { // 배열에서 랜덤 선택
                        return
                    }

                    // 텍스트 라벨 업데이트 (선택된 감정 표시)
                    self.emotionTitleLabel.text = "감정별 추천 - \(selectedEmotionForRecommendation)"
                    self.recommendedEmotionDiaries = []

                    // 2. 선택된 감정 기반으로 일기 추천
                    self.db.collection("users").document(userId).collection("diaries")
                        .whereField("emotion", isEqualTo: selectedEmotionForRecommendation) // ✅ 이제 이 변수를 사용
                        .order(by: "createdAt", descending: true)
                        .limit(to: 5) // 최대 5개 일기만 가져오기
                        .getDocuments { (snapshot, error) in
                            if let error = error {
                                let errorLabel = UILabel()
                                errorLabel.text = "오류: '\(selectedEmotionForRecommendation)' 감정 일기 가져오기 실패 (\(error.localizedDescription))"
                                errorLabel.font = .systemFont(ofSize: 15)
                                errorLabel.textColor = .systemRed
                                return
                            }

                         

                            let entries = snapshot?.documents.compactMap {
                                try? $0.data(as: Diary.self)
                            } ?? []

                            if entries.isEmpty {
                                let emptyLabel = UILabel()
                                emptyLabel.text = "'\(selectedEmotionForRecommendation)' 감정의 일기가 없습니다."
                                emptyLabel.font = .systemFont(ofSize: 15)
                                emptyLabel.textColor = .darkGray
                                
                                self.recommendedEmotionDiaries = []         // 💡 컬렉션 뷰 초기화
                                self.emotionCollectionView.reloadData()     // 💡 화면 갱신

                            } else {
                                print("감정 추천 일기 개수: \(entries.count)")

                                self.recommendedEmotionDiaries = entries    // 💡 데이터 저장
                                self.emotionCollectionView.reloadData()     // 💡 화면 갱신
                            }

                        }

                } catch {
                }
            }
    }
    


    private let emotionCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 9
        layout.itemSize = CGSize(width: 170, height: 100)
        layout.estimatedItemSize = .zero
        layout.sectionInset = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.showsHorizontalScrollIndicator = true
        //collectionView.clipsToBounds = false
        collectionView.backgroundColor = .clear
        collectionView.register(EmotionDiaryCell.self, forCellWithReuseIdentifier: "EmotionDiaryCell")
        return collectionView
    }()

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == todayCollectionView {
            return todayDiaries.count
        } else {
            return recommendedEmotionDiaries.count
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == todayCollectionView {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TodayDiaryCell", for: indexPath) as? TodayDiaryCell else {
                return UICollectionViewCell()
            }
            let diary = todayDiaries[indexPath.item]
            cell.configure(with: diary)
            return cell
        } else {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EmotionDiaryCell", for: indexPath) as? EmotionDiaryCell else {
                return UICollectionViewCell()
            }
            let diary = recommendedEmotionDiaries[indexPath.item]
            cell.configure(with: diary)
            return cell
        }
    }

    private func fetchFrequentLocations(for userId: String) {
        db.collection("users").document(userId).collection("diaries")
            .getDocuments { snapshot, error in
                if let error = error {
                    self.locationLabel.text = "오류: \(error.localizedDescription)"
                    return
                }

                var locationCount: [String: Int] = [:]
                let entries = snapshot?.documents.compactMap {
                    try? $0.data(as: Diary.self)
                } ?? []

                for entry in entries {
                    let key = entry.locationName ?? "이름 없는 장소"
                    locationCount[key, default: 0] += 1
                }

                let sorted = locationCount.sorted { $0.value > $1.value }
                let top3 = sorted.prefix(3).map { "- \($0.key): \($0.value)회" }.joined(separator: "\n")

                self.locationLabel.text = top3.isEmpty ? "기록된 장소가 없습니다." : top3
            }
    }
}

fileprivate func SectionTitleLabel(_ text: String) -> UILabel {
    let label = UILabel()
    label.text = text
    label.font = .boldSystemFont(ofSize: 20)
    label.textColor = .label
    label.numberOfLines = 1
    label.translatesAutoresizingMaskIntoConstraints = false
    return label
}

private func SectionContentLabel() -> UILabel {
    let label = UILabel()
    label.font = .systemFont(ofSize: 15)
    label.textColor = .darkGray
    label.numberOfLines = 0
    return label
}


extension MypageViewController: UICollectionViewDataSource, UICollectionViewDelegate {



    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedDiary: Diary

        if collectionView == todayCollectionView {
            selectedDiary = todayDiaries[indexPath.item]
        } else if collectionView == emotionCollectionView {
            
            selectedDiary = recommendedEmotionDiaries[indexPath.item]
        } else {
            return // 알 수 없는 컬렉션 뷰일 경우 처리하지 않음
        }

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let detailVC = storyboard.instantiateViewController(withIdentifier: "DiaryDetailViewController") as? DiaryDetailViewController {
            detailVC.diary = selectedDiary
            navigationController?.pushViewController(detailVC, animated: true)
        }
    }

}
