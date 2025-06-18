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
        textField.isUserInteractionEnabled = false // ✅ 제목은 수정 불가능하게 설정 (탭하여 수정 모드로 전환 시 변경 가능하도록 구현 고려)
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
        textView.isEditable = true // ✅ 내용은 수정 가능하게 유지
        textView.translatesAutoresizingMaskIntoConstraints = false // ✅ 추가: 코드 기반 제약 조건 사용
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) // 패딩 없앰
        textView.textContainer.lineFragmentPadding = 0 // 패딩 없앰
        return textView
    }()

    // ✅ contentTextView의 bottomAnchor 제약 조건을 저장할 변수
    private var contentTextViewBottomConstraint: NSLayoutConstraint?

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        displayDiary()
        setupNavigationBar()
        setupKeyboardObservers() // ✅ 키보드 옵저버 등록
    }
    
    // ✅ deinit에 옵저버 제거 추가
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup
    
    private func setupUI() {
        [locationLabel, titleTextField, separatorView, contentTextView].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        // ✅ contentTextViewBottomConstraint 초기화
        contentTextViewBottomConstraint = contentTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        
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
            contentTextViewBottomConstraint! // ✅ 저장된 제약 조건 사용
        ])
    }
    
    private func displayDiary() {
        guard let diary = diary else { return }
        navigationItem.title = diary.formattedDate
        titleTextField.text = diary.title
        contentTextView.text = diary.content
    }
    
    private func setupNavigationBar() {
        let dateLabel = UILabel()
        dateLabel.text = diary?.formattedDate ?? "날짜 없음"
        dateLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        dateLabel.textColor = .secondaryLabel
        dateLabel.sizeToFit()
        navigationItem.titleView = dateLabel

        // 오른쪽에 '수정' 버튼 추가 (원래 코드에서는 '완료' 버튼이었으나, 내용만 수정 가능하므로 '수정'이 더 적절할 수 있음)
        // 만약 '수정' 버튼을 눌렀을 때 제목도 수정 가능하도록 전환하고 싶다면 로직 추가 필요
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "저장", // ✅ '완료' 대신 '저장'으로 변경 제안 (수정 후 저장 의미 명확히)
            style: .done,
            target: self,
            action: #selector(saveButtonTapped)
        )
    }
    
    // MARK: - Keyboard Observers
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        
        // 키보드 높이에 맞게 contentTextView의 하단 제약 조건 조정
        let newBottomConstant = -keyboardFrame.height + view.safeAreaInsets.bottom
        
        UIView.animate(withDuration: duration) {
            self.contentTextViewBottomConstraint?.constant = newBottomConstant
            self.view.layoutIfNeeded()
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        
        // 키보드가 사라지면 원래 위치로 되돌림
        UIView.animate(withDuration: duration) {
            self.contentTextViewBottomConstraint?.constant = -20 // 원래 초기값
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Actions
    
    @objc private func saveButtonTapped() {
        // 제목은 수정 불가능하므로, 원래 diary.title 사용
        let originalTitle = diary?.title ?? "제목 없음"
        let updatedContent = contentTextView.text ?? ""
        
        guard let diaryID = diary?.id else {
            print("⚠️ Diary ID가 없습니다.")
            // 사용자에게 알림 표시 (예: "수정할 일기를 찾을 수 없습니다.")
            return
        }
        
        // 내용이 비어있지 않은지 확인 (선택 사항)
        guard !updatedContent.isEmpty else {
            let alert = UIAlertController(title: "내용 없음", message: "일기 내용은 비워둘 수 없습니다.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default))
            present(alert, animated: true)
            return
        }

        updateDiaryInFirestore(documentID: diaryID, title: originalTitle, content: updatedContent)
    }

    private func updateDiaryInFirestore(documentID: String, title: String, content: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        
        let documentRef = db.collection("users").document(userId).collection("diaries").document(documentID)
        
        documentRef.updateData([
            "title": title, // 제목은 수정 안하지만, 필드 유지
            "content": content,
            "updatedAt": FieldValue.serverTimestamp() // ✅ 수정 시간 업데이트
        ]) { error in
            if let error = error {
                print("❌ 데이터 수정 실패: \(error.localizedDescription)")
                let alert = UIAlertController(title: "저장 실패", message: "일기 수정에 실패했습니다: \(error.localizedDescription)", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "확인", style: .default))
                self.present(alert, animated: true)
            } else {
                print("✅ 데이터 수정 완료")
                // 사용자에게 성공 알림 표시 후 이전 화면으로 돌아가기
                let alert = UIAlertController(title: "수정 완료", message: "일기가 성공적으로 수정되었습니다.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in
                    self.navigationController?.popViewController(animated: true)
                })
                self.present(alert, animated: true)
            }
        }
    }
}
