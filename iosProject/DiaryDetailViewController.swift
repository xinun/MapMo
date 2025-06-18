// DiaryDetailViewController.swift 파일 전체를 이 코드로 교체하세요.

import UIKit
import FirebaseFirestore
import FirebaseAuth

class DiaryDetailViewController: UIViewController {

    // HomeViewController에서 전달받을 일기 데이터를 담을 변수
    var diary: Diary?

    // MARK: - UI Components
    
    private lazy var locationLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemGray
        // 맵 아이콘과 함께 표시하기 위해 아이콘 추가
        let attachment = NSTextAttachment()
        attachment.image = UIImage(systemName: "mappin.and.ellipse")?.withTintColor(.systemGray)
        attachment.bounds = CGRect(x: 0, y: -2, width: 14, height: 14)
        let attributedString = NSMutableAttributedString(attachment: attachment)
        attributedString.append(NSAttributedString(string: " " + (diary?.locationTitle ?? "위치 정보 없음")))
        label.attributedText = attributedString
        return label
    }()
    
    private lazy var titleTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "제목"
        textField.font = .systemFont(ofSize: 24, weight: .bold)
        textField.borderStyle = .none
        return textField
    }()
    
    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray5
        return view
    }()
    
    private lazy var contentTextView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 17)
        textView.isEditable = true
        return textView
    }()

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        displayDiary()
        setupNavigationBar()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        [locationLabel, titleTextField, separatorView, contentTextView].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            locationLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            locationLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            locationLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            titleTextField.topAnchor.constraint(equalTo: locationLabel.bottomAnchor, constant: 16),
            titleTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            separatorView.topAnchor.constraint(equalTo: titleTextField.bottomAnchor, constant: 12),
            separatorView.leadingAnchor.constraint(equalTo: titleTextField.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: titleTextField.trailingAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 1),
            
            contentTextView.topAnchor.constraint(equalTo: separatorView.bottomAnchor, constant: 16),
            contentTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contentTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contentTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    private func displayDiary() {
        // 전달받은 diary 객체의 내용으로 UI를 채웁니다.
        guard let diary = diary else { return }
        navigationItem.title = diary.formattedDate // 네비게이션 바 제목을 날짜로 설정
        titleTextField.text = diary.title
        contentTextView.text = diary.content
    }
    
    private func setupNavigationBar() {
        // ✅ 네비게이션 바 중앙에 날짜를 표시
        let dateLabel = UILabel()
        dateLabel.text = diary?.formattedDate ?? "날짜 없음"
        dateLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        dateLabel.textColor = .secondaryLabel
        dateLabel.sizeToFit()
        navigationItem.titleView = dateLabel

        // ✅ 오른쪽에 '완료' 버튼 유지
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "완료",
            style: .done,
            target: self,
            action: #selector(saveButtonTapped)
        )
    }


    // MARK: - Actions
    
    @objc private func saveButtonTapped() {
        let updatedTitle = titleTextField.text ?? "제목 없음"
        let updatedContent = contentTextView.text ?? ""
        
        guard let diaryID = diary?.id else {
            print("⚠️ Diary ID가 없습니다.")
            return
        }
        
        updateDiaryInFirestore(documentID: diaryID, title: updatedTitle, content: updatedContent)
    }

    private func updateDiaryInFirestore(documentID: String, title: String, content: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        let documentRef = db.collection("users").document(userId).collection("diaries").document(documentID)
        
        documentRef.updateData([
            "title": title,
            "content": content
        ]) { error in
            if let error = error {
                print("❌ 데이터 수정 실패: \(error.localizedDescription)")
                // TODO: 사용자에게 실패 알림 팝업 표시
            } else {
                print("✅ 데이터 수정 완료")
                self.navigationController?.popViewController(animated: true)
            }
        }
    }
}
