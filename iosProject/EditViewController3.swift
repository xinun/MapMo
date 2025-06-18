import UIKit
import FirebaseAuth
import FirebaseFirestore
import NMapsMap

// UITextView의 Placeholder 기능을 위해 Delegate 채택
class EditViewController3: UIViewController, UITextViewDelegate {

    // MARK: - Properties
    
    var selectedTags: [String] = []
    var locationInfo: LocationInfo?
    var coordinates: NMGLatLng?
    var selectedEmotion: String? // ✅ 선택된 감정을 저장할 새로운 변수

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemGray
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일"
        label.text = formatter.string(from: Date())
        return label
    }()
    
    private lazy var tagsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .systemGray2
        label.text = selectedTags.map { "#\($0)" }.joined(separator: " ")
        return label
    }()
    
    private let titleField: UITextField = {
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
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.text = "어떤 일이 있었나요? 오늘의 감정과 생각을 자유롭게 기록해보세요."
        textView.textColor = .systemGray3
        textView.delegate = self
        return textView
    }()
    
    private lazy var saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("일기 저장하기", for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 18)
        button.backgroundColor = UIColor(red: 88/255, green: 86/255, blue: 214/255, alpha: 1.0) // Soft Indigo
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 14
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 4)
        button.layer.shadowRadius = 8.0
        button.layer.shadowOpacity = 0.2
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        return button
    }()

    // --- 로딩 UI 컴포넌트 ---
    private let overlayView = UIView()
    private let loadingContainerView = UIView()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let loadingLabel = UILabel()
    private let percentageLabel = UILabel()
    
    private var progressTimer: Timer?
    private var currentProgress: Int = 0
    
    private var saveButtonBottomConstraint: NSLayoutConstraint?

    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        setupKeyboardObservers()
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard)))
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let locationInfo = self.locationInfo else {
              print("⚠️ 위치 정보가 없어 일기를 생성할 수 없습니다.")
              // 필요하다면 사용자에게 알림 표시
              return
          }
        showLoading()
        generateDiary(from: selectedTags, locationInfo: locationInfo) { [weak self] diaryText in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.hideLoading {
                    if let diaryText = diaryText, !diaryText.contains("❌") {
                        let (title, content) = self.splitTitleAndContent(from: diaryText)
                        self.titleField.text = title
                        self.contentTextView.text = content
                        self.contentTextView.textColor = .label
                    } else {
                        self.titleField.text = "❌ 일기 생성 실패"
                        self.contentTextView.text = "API 호출에 실패했습니다.\nXcode 콘솔의 에러 메시지를 확인해주세요."
                        self.contentTextView.textColor = .systemRed
                    }
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        progressTimer?.invalidate()
        progressTimer = nil
    }

    // MARK: - UI Setup
    
    private func setupUI() {
        [dateLabel, tagsLabel, titleField, separatorView, contentTextView, saveButton].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        setupLoadingUI()
        
        saveButtonBottomConstraint = saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        
        NSLayoutConstraint.activate([
            dateLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            dateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            dateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            tagsLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 4),
            tagsLabel.leadingAnchor.constraint(equalTo: dateLabel.leadingAnchor),
            tagsLabel.trailingAnchor.constraint(equalTo: dateLabel.trailingAnchor),

            titleField.topAnchor.constraint(equalTo: tagsLabel.bottomAnchor, constant: 16),
            titleField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            separatorView.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 12),
            separatorView.leadingAnchor.constraint(equalTo: titleField.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: titleField.trailingAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 1),
            
            contentTextView.topAnchor.constraint(equalTo: separatorView.bottomAnchor, constant: 16),
            contentTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contentTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contentTextView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -20),
            
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            saveButton.heightAnchor.constraint(equalToConstant: 52),
            saveButtonBottomConstraint!,
        ])
    }
    
    // MARK: - Keyboard & TextView Delegate
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        
        let newBottomConstant = -keyboardFrame.height + view.safeAreaInsets.bottom
        
        UIView.animate(withDuration: duration) {
            self.saveButtonBottomConstraint?.constant = newBottomConstant
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        
        UIView.animate(withDuration: duration) {
            self.saveButtonBottomConstraint?.constant = -20
            self.view.layoutIfNeeded()
        }
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == .systemGray3 {
            textView.text = nil
            textView.textColor = .label
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = "어떤 일이 있었나요? 오늘의 감정과 생각을 자유롭게 기록해보세요."
            textView.textColor = .systemGray3
        }
    }

    // MARK: - Loading Indicator Methods
    
    private func setupLoadingUI() {
        overlayView.backgroundColor = UIColor(white: 0, alpha: 0.4)
        loadingContainerView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        loadingContainerView.layer.cornerRadius = 16
        activityIndicator.color = .white
        loadingLabel.text = "AI가 일기를 생성 중입니다..."
        loadingLabel.textColor = .white
        loadingLabel.font = .systemFont(ofSize: 16, weight: .medium)
        percentageLabel.textColor = .white
        percentageLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        
        [overlayView, loadingContainerView].forEach { view.addSubview($0); $0.translatesAutoresizingMaskIntoConstraints = false }
        [activityIndicator, loadingLabel, percentageLabel].forEach { loadingContainerView.addSubview($0); $0.translatesAutoresizingMaskIntoConstraints = false }
        
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingContainerView.widthAnchor.constraint(equalToConstant: 250),
            activityIndicator.topAnchor.constraint(equalTo: loadingContainerView.topAnchor, constant: 20),
            activityIndicator.centerXAnchor.constraint(equalTo: loadingContainerView.centerXAnchor),
            loadingLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 12),
            loadingLabel.centerXAnchor.constraint(equalTo: loadingContainerView.centerXAnchor),
            percentageLabel.topAnchor.constraint(equalTo: loadingLabel.bottomAnchor, constant: 8),
            percentageLabel.centerXAnchor.constraint(equalTo: loadingContainerView.centerXAnchor),
            percentageLabel.bottomAnchor.constraint(equalTo: loadingContainerView.bottomAnchor, constant: -20)
        ])
        
        overlayView.isHidden = true
        loadingContainerView.isHidden = true
    }
    
    private func showLoading() {
        currentProgress = 0
        percentageLabel.text = "\(currentProgress)%"
        overlayView.alpha = 0
        loadingContainerView.alpha = 0
        loadingContainerView.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        overlayView.isHidden = false
        loadingContainerView.isHidden = false
        activityIndicator.startAnimating()
        
        UIView.animate(withDuration: 0.3) {
            self.overlayView.alpha = 1
            self.loadingContainerView.alpha = 1
            self.loadingContainerView.transform = .identity
        }
        
        progressTimer = Timer.scheduledTimer(timeInterval: 0.15, target: self, selector: #selector(updateProgress), userInfo: nil, repeats: true)
    }
    
    @objc private func updateProgress() {
        if currentProgress < 99 {
            currentProgress += Int.random(in: 1...2)
            currentProgress = min(currentProgress, 99)
            percentageLabel.text = "\(currentProgress)%"
        } else {
            progressTimer?.invalidate()
            progressTimer = nil
        }
    }

    private func hideLoading(completion: @escaping () -> Void) {
        progressTimer?.invalidate()
        progressTimer = nil
        currentProgress = 100
        percentageLabel.text = "\(currentProgress)%"
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UIView.animate(withDuration: 0.3, animations: {
                self.overlayView.alpha = 0
                self.loadingContainerView.alpha = 0
            }) { _ in
                self.activityIndicator.stopAnimating()
                self.overlayView.isHidden = true
                self.loadingContainerView.isHidden = true
                completion()
            }
        }
    }
    
    // MARK: - Actions & Methods
    
    @objc private func saveButtonTapped() {
        let title = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "제목 없음"
        let content = contentTextView.text ?? ""

        guard !content.isEmpty, contentTextView.textColor != .systemGray3 else {
            print("⚠️ 내용이 비어있음")
            return
        }
        guard let locationInfo = locationInfo, let coordinates = coordinates else {
                 print("⚠️ 위치 정보 또는 좌표가 전달되지 않았습니다.")
                 // 사용자에게 알림을 띄워주는 것이 좋습니다.
                 return
             }
        saveButton.isEnabled = false
        saveDiaryToFirestore(title: title, content: content, tags: selectedTags, locationInfo: locationInfo, coordinates: coordinates) { [weak self] success in
            DispatchQueue.main.async {
                self?.saveButton.isEnabled = true
                if success { self?.showSaveConfirmation() }
            }
        }
    }

    private func showSaveConfirmation() {
        let alert = UIAlertController(title: "저장 완료", message: "일기가 저장되었습니다.", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "확인", style: .default, handler: { _ in
            
            // 💡 앱의 화면을 관리하는 SceneDelegate를 가져옵니다.
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let sceneDelegate = windowScene.delegate as? SceneDelegate else {
                return
            }
            
            // ✅ 1. 스토리보드에서 TabBarController를 새로 생성합니다.
            //    (스토리보드 파일 이름이 'Main.storyboard'가 아니라면 해당 이름으로 수정해주세요)
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let tabBarController = storyboard.instantiateViewController(withIdentifier: "TabBarController") as! TabBarController
            
            // ✅ 2. 원하는 탭으로 이동시킵니다. (두 번째 탭)
            tabBarController.selectedIndex = 1
            
            // ✅ 3. 앱의 메인 화면(root)을 이 TabBarController로 교체합니다.
            sceneDelegate.window?.rootViewController = tabBarController
            sceneDelegate.window?.makeKeyAndVisible()
            
            // 부드러운 화면 전환 효과를 줍니다.
            if let window = sceneDelegate.window {
                UIView.transition(with: window,
                                  duration: 0.3,
                                  options: .transitionCrossDissolve,
                                  animations: nil,
                                  completion: nil)
            }
        }))
        
        present(alert, animated: true)
    }


    private func splitTitleAndContent(from text: String) -> (title: String, content: String) {
        let lines = text.components(separatedBy: .newlines)
        if let titleLine = lines.first(where: { $0.hasPrefix("제목:") }) {
            let title = titleLine.replacingOccurrences(of: "제목:", with: "").trimmingCharacters(in: .whitespaces)
            let content = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return (title, content)
        }
        return ("일기", text)
    }

    func updateEmotionStats(userId: String, emotion: String) {
        let ref = Firestore.firestore()
            .collection("users")
            .document(userId)
            .collection("emotionStats")
            .document("summary")
        
        ref.setData([
            "counts.\(emotion)": FieldValue.increment(Int64(1))
        ], merge: true)
    }


    private func saveDiaryToFirestore(title: String, content: String, tags: [String], locationInfo: LocationInfo, coordinates: NMGLatLng, completion: @escaping (Bool) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }

        // Firestore GeoPoint는 Double 위도/경도로 충분하므로, GeoPoint(latitude: coordinates.lat, longitude: coordinates.lng) 이 부분은 데이터를 Firestore에 저장할 때 사용하세요.
        // Diary 모델에 직접 GeoPoint 타입을 저장하지 않는다면 필요 없습니다.
        // 현재 Diary 모델은 Double latitude/longitude를 사용하므로 이 줄은 주석 처리하거나 제거해도 됩니다.
        // let geoPoint = GeoPoint(latitude: coordinates.lat, longitude: coordinates.lng)

        let createdAt = Timestamp()
        let dateFormatter = DateFormatter.monthDayFormatter
        let monthDay = dateFormatter.string(from: createdAt.dateValue()) // Cloud Functions가 자동으로 추가하므로 여기선 필수는 아님

        // 감정은 첫 번째 태그가 아니라, 사용자가 명시적으로 선택한 감정 필드가 있다면 그것을 사용하는 것이 좋습니다.
        // 현재 코드에서는 tags.first를 emotion으로 사용하고 있으니, 이대로 진행하겠습니다.
        let emotionToSave = self.selectedEmotion ?? "미분류"
        let data: [String: Any] = [
            "userId": userId,
            "title": title,
            "content": content,
            "tags": tags,
            "createdAt": createdAt,
            "updatedAt": FieldValue.serverTimestamp(),
            "monthDay": monthDay, // Cloud Functions에서 추가되지만, 앱에서도 넣어줘도 무방
            "locationName": locationInfo.title,
            "address": locationInfo.subtitle ?? "",
            "latitude": coordinates.lat,
            "longitude": coordinates.lng,
            "emotion": emotionToSave
        ]

        let db = Firestore.firestore()
        db.collection("users").document(userId).collection("diaries").addDocument(data: data) { error in
            if let error = error {
                print("❌ 일기 저장 실패: \(error.localizedDescription)")
                completion(false)
            } else {
                print("✅ 일기 저장 완료")
                // ✅ 감정 통계 업데이트 호출
                // 이 updateEmotionStats 함수는 클라이언트에서 호출해도 되고,
                // Firebase Cloud Functions (index.js)에서 onWrite 트리거로 자동 처리하게 할 수도 있습니다.
                // Cloud Functions로 이미 구현했다면 이 클라이언트 측 호출은 필요 없습니다.
                // self.updateEmotionStats(userId: userId, emotion: emotion)
                completion(true)
            }
        }
    }

    // 이 updateEmotionStats 함수는 Cloud Functions에서 이미 구현했으므로,
    // EditViewController3에서는 제거해도 됩니다.
    // func updateEmotionStats(userId: String, emotion: String) {
    //     let ref = Firestore.firestore()
    //             .collection("users")
    //             .document(userId)
    //             .collection("emotionStats")
    //             .document("summary")
    //
    //     ref.setData([
    //         "counts.\(emotion)": FieldValue.increment(Int64(1))
    //     ], merge: true)
    // }

    private func generateDiary(from tags: [String], locationInfo: LocationInfo, completion: @escaping (String?) -> Void) {
        let prompt = """
        아래 키워드와 장소 정보를 바탕으로 감성적인 오늘 하루의 일기를 작성해줘.
        일기는 태그별로 1~2 문장으로 요약하고, 전체적으로 자연스럽고 부드러운 문체로 써줘.
        첫 문장은 '제목: ~' 형식으로 시작해줘.

        [오늘의 태그]
        \(tags.joined(separator: ", "))

        [오늘의 장소]
        \(locationInfo.title)

        [장소 활용법]
        - 만약 '오늘의 장소'가 공원, 궁궐, 관광지, 특별한 카페나 식당처럼 구체적인 활동을 연상할 수 있는 곳이라면, 그 장소에서의 경험을 상상해서 일기에 자연스럽게 녹여내 줘.
        - 만약 '오늘의 장소'가 아파트, 일반 빌딩, 또는 그냥 주소처럼 구체적인 활동을 떠올리기 힘든 곳이라면, 그 장소 자체보다는 그 '주변의 가볼 만한 곳'이나 '인기 있는 장소'를 자유롭게 상상해서 그곳에서의 경험을 일기에 포함시켜 줘.
        """
        let messages = [GPTMessage(role: "user", content: prompt)]
        let request = GPTRequest(model: "gpt-4o", messages: messages)

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions"),
              let apiKey = Bundle.main.infoDictionary?["GPT_API_KEY"] as? String else {
            print("❌ API URL 또는 키 없음. Info.plist를 확인하세요.")
            completion(nil)
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            print("❌ 인코딩 실패: \(error)")
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                print("❌ 네트워크 에러: \(error.localizedDescription)")
                completion(nil)
                return
            }
            guard let data = data else {
                print("❌ 데이터 없음")
                completion(nil)
                return
            }
            if let decoded = try? JSONDecoder().decode(GPTResponse.self, from: data),
               let diary = decoded.choices.first?.message.content {
                completion(diary)
            } else {
                let responseString = String(data: data, encoding: .utf8) ?? "디코딩 불가"
                print("❌ GPT 응답이 올바르지 않습니다. 응답 내용: \(responseString)")
                completion("❌ GPT 응답이 올바르지 않습니다.")
            }
        }.resume()
    }
}

// MARK: - GPT Data Models

struct GPTRequest: Codable {
    let model: String
    let messages: [GPTMessage]
}

struct GPTMessage: Codable {
    let role: String
    let content: String
}

struct GPTResponse: Codable {
    struct Choice: Codable {
        let message: GPTMessage
    }
    let choices: [Choice]
}
