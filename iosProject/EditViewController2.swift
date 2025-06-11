import UIKit
import NMapsMap

class EditViewController2: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    var locationInfo: LocationInfo?
    var coordinates: NMGLatLng?
    
    var loopedOptions: [[DiaryThemeOption]] = []
    var autoScrollTimers: [Int: Timer] = [:]
    
    
    @IBAction func GotoMemo(_ sender: Any) {
        let selectedTags = getSelectedOptions()
        let vc = EditViewController3()
        vc.selectedTags = selectedTags
        vc.locationInfo = self.locationInfo
           vc.coordinates = self.coordinates
        self.present(vc, animated: true)
    }
    let themeSections: [DiaryThemeSection] = [
        DiaryThemeSection(question: "오늘의 기분은?", options: [
            DiaryThemeOption(title: "기쁨", iconName: "smiley"),
            DiaryThemeOption(title: "슬픔", iconName: "cloud.drizzle"),
            DiaryThemeOption(title: "화남", iconName: "flame"),
            DiaryThemeOption(title: "편안함", iconName: "leaf"),
            DiaryThemeOption(title: "무기력함", iconName: "zzz"),
            DiaryThemeOption(title: "혼란스러움", iconName: "questionmark")
        ]),
        
        DiaryThemeSection(question: "하루의 분위기는 어땠나요?", options: [
            DiaryThemeOption(title: "바쁨", iconName: "hare"),
            DiaryThemeOption(title: "여유로움", iconName: "tortoise"),
            DiaryThemeOption(title: "생산적이었음", iconName: "chart.bar"),
            DiaryThemeOption(title: "지쳤음", iconName: "bed.double"),
            DiaryThemeOption(title: "생각이 많았음", iconName: "brain")
        ]),
        
        DiaryThemeSection(question: "오늘 무엇을 했나요?", options: [
            DiaryThemeOption(title: "맛집 탐방", iconName: "fork.knife"),
            DiaryThemeOption(title: "영화 보기", iconName: "film"),
            DiaryThemeOption(title: "운동", iconName: "figure.walk"),
            DiaryThemeOption(title: "공부", iconName: "book"),
            DiaryThemeOption(title: "게임", iconName: "gamecontroller"),
            DiaryThemeOption(title: "쇼핑", iconName: "bag")
        ]),
        
        DiaryThemeSection(question: "오늘의 날씨는?", options: [
            DiaryThemeOption(title: "맑음", iconName: "sun.max"),
            DiaryThemeOption(title: "흐림", iconName: "cloud"),
            DiaryThemeOption(title: "비", iconName: "cloud.rain"),
            DiaryThemeOption(title: "눈", iconName: "snow"),
            DiaryThemeOption(title: "바람", iconName: "wind")
        ]),
        
        DiaryThemeSection(question: "누구와 보냈나요?", options: [
            DiaryThemeOption(title: "혼자", iconName: "person"),
            DiaryThemeOption(title: "가족", iconName: "house"),
            DiaryThemeOption(title: "친구", iconName: "person.2"),
            DiaryThemeOption(title: "연인", iconName: "heart"),
            DiaryThemeOption(title: "동료", iconName: "briefcase")
        ]),
        
        DiaryThemeSection(question: "기억에 남는 순간은?", options: [
            DiaryThemeOption(title: "특별한 이벤트", iconName: "sparkles"),
            DiaryThemeOption(title: "감정적인 일", iconName: "face.smiling.inverse"),
            DiaryThemeOption(title: "인상 깊은 대화", iconName: "text.bubble"),
            DiaryThemeOption(title: "배움이나 깨달음", iconName: "lightbulb"),
            DiaryThemeOption(title: "안 좋았던 일", iconName: "exclamationmark.triangle")
        ])
    ]
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        autoScrollTimers.values.forEach { $0.invalidate() }
        autoScrollTimers.removeAll()
    }


    // 선택된 index 저장용
    var selectedIndices: [Int: Int] = [:]
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        startAutoScroll()

    }
    func startAutoScroll() {
        for subview in view.subviews {
            if let collectionView = subview as? UICollectionView {
                let tag = collectionView.tag
                autoScrollTimers[tag]?.invalidate()

                // ✅ 0.3~1.0 사이의 랜덤 속도 생성
                let randomSpeed = CGFloat.random(in: 0.3...1.0)

                let timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak collectionView] _ in
                    guard let cv = collectionView else { return }
                    let offsetX = cv.contentOffset.x + randomSpeed
                    let maxOffsetX = cv.contentSize.width - cv.bounds.width
                    if offsetX >= maxOffsetX {
                        cv.contentOffset.x = 0
                    } else {
                        cv.contentOffset.x = offsetX
                    }
                }

                RunLoop.main.add(timer, forMode: .common)
                autoScrollTimers[tag] = timer
            }
        }
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        loopedOptions = themeSections.map { section in
              Array(repeating: section.options, count: 3).flatMap { $0 }
          }
        
        view.backgroundColor = .white

        var previousBottom: NSLayoutYAxisAnchor = view.safeAreaLayoutGuide.topAnchor

        for (index, section) in themeSections.enumerated() {
            let questionLabel = UILabel()
            questionLabel.text = section.question
            questionLabel.font = .boldSystemFont(ofSize: 18)
            questionLabel.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(questionLabel)

            NSLayoutConstraint.activate([
                questionLabel.topAnchor.constraint(equalTo: previousBottom, constant: 24),
                questionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16)
            ])

            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .horizontal
            layout.itemSize = CGSize(width: 120, height: 40)
            layout.minimumLineSpacing = 8

            let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
            collectionView.translatesAutoresizingMaskIntoConstraints = false
            collectionView.backgroundColor = .clear
            collectionView.tag = index
            collectionView.dataSource = self
            collectionView.delegate = self
            collectionView.decelerationRate = .fast
            collectionView.showsHorizontalScrollIndicator = false

            collectionView.register(TagCell.self, forCellWithReuseIdentifier: "TagCell")

            view.addSubview(collectionView)

            NSLayoutConstraint.activate([
                collectionView.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 8),
                collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                collectionView.heightAnchor.constraint(equalToConstant: 50)
            ])

            previousBottom = collectionView.bottomAnchor
        }
    }

    // MARK: - UICollectionViewDataSource

    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return loopedOptions[collectionView.tag].count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let option = loopedOptions[collectionView.tag][indexPath.item]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TagCell", for: indexPath) as! TagCell
        let isSelected = selectedIndices[collectionView.tag] == indexPath.item
        cell.configure(with: option, selected: isSelected)
        return cell
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let collectionView = scrollView as? UICollectionView else { return }

        let total = loopedOptions[collectionView.tag].count
        let original = themeSections[collectionView.tag].options.count

        let currentOffset = scrollView.contentOffset.x
        let contentWidth = scrollView.contentSize.width
        let itemWidth: CGFloat = 120 + 8

        if currentOffset < itemWidth {
            // 왼쪽 끝 가까우면 중앙으로 이동
            let newOffset = currentOffset + itemWidth * CGFloat(original)
            scrollView.contentOffset.x = newOffset
        } else if currentOffset > contentWidth - itemWidth * CGFloat(original + 1) {
            // 오른쪽 끝 가까우면 중앙으로 이동
            let newOffset = currentOffset - itemWidth * CGFloat(original)
            scrollView.contentOffset.x = newOffset
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard let collectionView = scrollView as? UICollectionView else { return }
        autoScrollTimers[collectionView.tag]?.invalidate()
        autoScrollTimers[collectionView.tag] = nil
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard let collectionView = scrollView as? UICollectionView else { return }
        let tag = collectionView.tag
        // 일정 시간 후 자동 스크롤 재시작
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.autoScrollTimers[tag]?.invalidate()
            self.autoScrollTimers[tag] = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak collectionView] _ in
                guard let cv = collectionView else { return }
                let offsetX = cv.contentOffset.x + 0.5
                let maxOffsetX = cv.contentSize.width - cv.bounds.width
                if offsetX >= maxOffsetX {
                    cv.contentOffset.x = 0
                } else {
                    cv.contentOffset.x = offsetX
                }
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedIndices[collectionView.tag] = indexPath.item
        collectionView.reloadData()

        if let cell = collectionView.cellForItem(at: indexPath) {
            UIView.animate(withDuration: 0.3,
                           delay: 0,
                           usingSpringWithDamping: 0.5,
                           initialSpringVelocity: 0.5,
                           options: [],
                           animations: {
                cell.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            }) { _ in
                UIView.animate(withDuration: 0.2) {
                    cell.transform = .identity
                }
            }
        }
    }


    func getSelectedOptions() -> [String] {
        return selectedIndices.compactMap { (sectionIndex, itemIndex) in
            let originalCount = themeSections[sectionIndex].options.count
            let actualIndex = itemIndex % originalCount
            return themeSections[sectionIndex].options[actualIndex].title
        }
    }


}
struct DiaryThemeOption {
    let title: String
    let iconName: String
}

struct DiaryThemeSection {
    let question: String
    let options: [DiaryThemeOption]
}
