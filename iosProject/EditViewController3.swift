import UIKit

class EditViewController2: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    let themeSections: [DiaryThemeSection] = [
        DiaryThemeSection(question: "오늘의 기분은?", options: [
            DiaryThemeOption(title: "기쁨", iconName: "face.smiling"),
            DiaryThemeOption(title: "슬픔", iconName: "cloud.drizzle"),
            DiaryThemeOption(title: "신남", iconName: "sun.max")
        ]),
        DiaryThemeSection(question: "오늘은 어떤 하루였나요?", options: [
            DiaryThemeOption(title: "한가함", iconName: "leaf"),
            DiaryThemeOption(title: "바쁨", iconName: "flame")
        ])
    ]

    // 선택된 index 저장용
    var selectedIndices: [Int: Int] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
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
        return themeSections[collectionView.tag].options.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let option = themeSections[collectionView.tag].options[indexPath.item]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TagCell", for: indexPath) as! TagCell
        let isSelected = selectedIndices[collectionView.tag] == indexPath.item
        cell.configure(with: option, selected: isSelected)
        return cell
    }

    // MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedIndices[collectionView.tag] = indexPath.item
        collectionView.reloadData()
    }
    func getSelectedOptions() -> [String] {
        return selectedIndices.compactMap { (sectionIndex, itemIndex) in
            themeSections[sectionIndex].options[itemIndex].title
        }
    }

}
// MARK: - 데이터 모델 정의
struct DiaryThemeOption {
    let title: String
    let iconName: String
}

struct DiaryThemeSection {
    let question: String
    let options: [DiaryThemeOption]
}
