import UIKit
import FirebaseAuth
import FirebaseFirestore


protocol MemoCellDelegate: AnyObject {
    func memoCellDidLongPress(_ cell: MemoCell)
}
// MARK: - Home View Controller
class HomeViewController: UIViewController {
    // HomeViewController.swift 파일 상단, class HomeViewController 위에 추가
  
    // --- Properties ---
    private var diaries: [Diary] = [] // Firestore에서 불러온 일기들을 저장할 배열
    private var listener: ListenerRegistration? // 실시간 업데이트를 위한 리스너

    // --- UI Components ---
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 20
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .clear
        cv.showsVerticalScrollIndicator = false
        return cv
    }()
    
    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "작성된 일기가 없어요.\n오른쪽 아래 + 버튼을 눌러\n첫 일기를 작성해보세요."
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .systemGray
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupNavigationBar()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 화면이 나타날 때마다 데이터를 다시 불러옵니다 (실시간 업데이트).
        fetchDiaries()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 화면이 사라질 때 리스너를 제거하여 불필요한 리소스 낭비를 막습니다.
        listener?.remove()
    }

    // MARK: - Setup
    private func setupNavigationBar() {
        navigationItem.title = "메모"
        navigationController?.navigationBar.prefersLargeTitles = true
    }
    private let floatingButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false

        // 버튼 스타일
        button.setImage(
            UIImage(systemName: "plus")?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 28, weight: .bold)),
            for: .normal
        )
        button.tintColor = .white
        button.backgroundColor = .clear
        button.layer.cornerRadius = 28
        button.clipsToBounds = true

        // 그림자
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 8.0
        button.layer.shadowOpacity = 0.3

        return button
    }()


    private func setupUI() {
        view.addSubview(collectionView)
        view.addSubview(emptyStateLabel)
        view.addSubview(floatingButton)
        floatingButton.addTarget(self, action: #selector(didTapFloatingButton), for: .touchUpInside)

        NSLayoutConstraint.activate([
            floatingButton.widthAnchor.constraint(equalToConstant: 56),
            floatingButton.heightAnchor.constraint(equalToConstant: 56),
            floatingButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            floatingButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])

        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(MemoCell.self, forCellWithReuseIdentifier: MemoCell.identifier)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // 이미 그라데이션이 추가되어 있다면 중복 방지
        if floatingButton.layer.sublayers?.contains(where: { $0 is CAGradientLayer }) == false {
            let gradientLayer = CAGradientLayer()
            gradientLayer.colors = [
                UIColor.systemIndigo.withAlphaComponent(0.8).cgColor,
                UIColor.systemIndigo.withAlphaComponent(0.4).cgColor
            ]
            gradientLayer.startPoint = CGPoint(x: 0, y: 0)
            gradientLayer.endPoint = CGPoint(x: 1, y: 1)
            gradientLayer.frame = floatingButton.bounds
            gradientLayer.cornerRadius = 28

            floatingButton.layer.insertSublayer(gradientLayer, at: 0)
        }
    }

    @objc private func didTapFloatingButton() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let editVC = storyboard.instantiateViewController(withIdentifier: "EditViewController") as? EditViewController {
            navigationController?.pushViewController(editVC, animated: true)
        }
    }

    private func fetchDiaries() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ 로그인된 유저가 없습니다.")
            return
        }
        
        let db = Firestore.firestore()
        
        // 이전에 등록된 리스너가 있다면 제거
        listener?.remove()
        
        // createdAt 필드를 기준으로 내림차순 정렬하여 최신순으로 데이터를 가져옵니다.
        let query = db.collection("users").document(userId).collection("diaries").order(by: "createdAt", descending: true)
        
        self.listener = query.addSnapshotListener { [weak self] (querySnapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ 데이터 로딩 실패: \(error.localizedDescription)")
                return
            }
            
            guard let documents = querySnapshot?.documents else {
                print("ℹ️ 문서가 없습니다.")
                return
            }
            
            // documents를 Diary 모델로 디코딩합니다.
            self.diaries = documents.compactMap { document -> Diary? in
                try? document.data(as: Diary.self)
            }
            
            // 메인 스레드에서 UI 업데이트
            DispatchQueue.main.async {
                self.emptyStateLabel.isHidden = !self.diaries.isEmpty
                self.collectionView.reloadData()
            }
        }
    }
    private func showDeleteConfirmationAlert(for diary: Diary) {
        let alert = UIAlertController(title: "일기 삭제",
                                      message: "'\(diary.title)' 일기를 정말 삭제하시겠습니까?",
                                      preferredStyle: .alert)

        let deleteAction = UIAlertAction(title: "삭제", style: .destructive) { [weak self] _ in
            self?.deleteDiary(diary: diary)
        }
        let cancelAction = UIAlertAction(title: "취소", style: .cancel, handler: nil)

        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
    private func deleteDiary(diary: Diary) {
        guard let userId = Auth.auth().currentUser?.uid, let diaryId = diary.id else {
            print("⚠️ 사용자 ID 또는 일기 ID가 없습니다.")
            return
        }

        let db = Firestore.firestore()
        db.collection("users").document(userId).collection("diaries").document(diaryId).delete { error in
            if let error = error {
                print("❌ 일기 삭제 실패: \(error.localizedDescription)")
                // 사용자에게 실패 알림 표시 (선택 사항)
            } else {
                print("✅ 일기 삭제 완료: \(diary.title)")
                // Firestore 리스너(addSnapshotListener)를 사용하고 있으므로,
                // 데이터를 다시 fetch할 필요 없이 자동으로 collectionView가 업데이트됩니다.
            }
        }
    }
}

// MARK: - CollectionView Delegate & DataSource
extension HomeViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return diaries.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MemoCell.identifier, for: indexPath) as? MemoCell else {
            return UICollectionViewCell()
        }
        let diary = diaries[indexPath.item]
        cell.configure(with: diary)
        cell.delegate = self
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // 셀의 너비를 화면 너비에 맞게 조정
        return CGSize(width: view.frame.width - 40, height: 160)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        // 상하 여백 추가
        return UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
    }
    
    // TODO: 셀을 탭했을 때의 동작 (상세보기 화면으로 이동)
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedDiary = diaries[indexPath.item]
        print("선택된 일기: \(selectedDiary.title)")
        guard let detailVC = storyboard?.instantiateViewController(withIdentifier: "DiaryDetailViewController") as? DiaryDetailViewController else {
            return
        }
        
        detailVC.diary = selectedDiary
        
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
}

extension HomeViewController: MemoCellDelegate {
    func memoCellDidLongPress(_ cell: MemoCell) {
        guard let indexPath = collectionView.indexPath(for: cell) else { return }
        let diaryToDelete = diaries[indexPath.item]
        showDeleteConfirmationAlert(for: diaryToDelete)
    }
}
// MARK: - Memo Cell
class MemoCell: UICollectionViewCell {
    static let identifier = "MemoCell"
    weak var delegate: MemoCellDelegate?
    // --- UI Components ---
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .systemGray
        return label
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .label
        label.numberOfLines = 1
        return label
    }()
    
    private let contentSnippetLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        return label
    }()
    private func setupLongPressGesture() {
          let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
          longPressGesture.minimumPressDuration = 0.5 // 0.5초 길게 누르면 인식
          self.addGestureRecognizer(longPressGesture)
      }
    private let tagsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .fill
        return stackView
    }()
    
    private let mainStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    // MARK: - Initializer
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
        setupLayout()
        setupLongPressGesture()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        // 재사용을 위해 태그 스택뷰를 비웁니다.
        tagsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
          if gesture.state == .began { // 길게 누르기 시작했을 때 한 번만 호출
              delegate?.memoCellDidLongPress(self) // ✅ 델리게이트에게 알림
          }
      }
    // MARK: - Setup
    private func setupCell() {
        backgroundColor = .systemBackground
        layer.cornerRadius = 16
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 12
    }
    
    private func setupLayout() {
        contentView.addSubview(mainStackView)
        
        mainStackView.addArrangedSubview(dateLabel)
        mainStackView.addArrangedSubview(titleLabel)
        mainStackView.addArrangedSubview(contentSnippetLabel)
        
        // 태그 스택뷰는 다른 요소들과 간격을 주기 위해 별도로 추가
        let spacer = UIView()
        mainStackView.addArrangedSubview(spacer)
        
        mainStackView.addArrangedSubview(tagsStackView)

        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            mainStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mainStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            mainStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            // title과 content의 높이를 상대적으로 조절
            titleLabel.heightAnchor.constraint(equalTo: mainStackView.heightAnchor, multiplier: 0.2),
            contentSnippetLabel.heightAnchor.constraint(equalTo: mainStackView.heightAnchor, multiplier: 0.3)
        ])
    }

    // MARK: - Configuration
    func configure(with diary: Diary) {
        dateLabel.text = diary.formattedDate
        titleLabel.text = diary.title
        contentSnippetLabel.text = diary.content
        
        // 기존 태그들을 지우고 새로 추가
        tagsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        diary.tags?.forEach { tagText in
            let tagLabel = createTagLabel(with: tagText)
            tagsStackView.addArrangedSubview(tagLabel)
        }

        // 태그가 너무 많을 경우를 대비
        tagsStackView.addArrangedSubview(UIView())
    }
    
    private func createTagLabel(with text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .systemIndigo
        label.backgroundColor = .systemIndigo.withAlphaComponent(0.1)
        label.layer.cornerRadius = 6
        label.clipsToBounds = true
        label.textAlignment = .center
        // 패딩을 주기 위해 NSAttributedString 사용
        let attributes: [NSAttributedString.Key: Any] = [.font: label.font!]
        let size = (text as NSString).size(withAttributes: attributes)
        label.widthAnchor.constraint(equalToConstant: size.width + 16).isActive = true
        return label
    }
}

