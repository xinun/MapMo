import UIKit
import Firebase
import GoogleSignIn
import FirebaseAuth
import FirebaseFirestore

class LoginViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        print("✅ LoginViewController loaded")
        setupGoogleLoginButton()
    }

    @IBOutlet weak var LogoImage: UIImageView!
   
    
    @objc func handleGoogleSignIn() {
        print("🟢 Google 버튼 눌림") // ← 이게 안 뜨면 버튼이 안 눌리는 상태!

        guard let clientID = FirebaseApp.app()?.options.clientID else { return }

        let config = GIDConfiguration(clientID: clientID)

        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(withPresenting: self) { result, error in
            if let error = error {
                print("❌ Google 로그인 에러: \(error.localizedDescription)")
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                print("❌ 사용자 정보 없음")
                return
            }

            let accessToken = user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)

            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("❌ Firebase 로그인 실패: \(error.localizedDescription)")
                } else {
                    print("✅ 로그인 성공")
                    if let user = Auth.auth().currentUser {
                        self.saveUserToFirestore(user: user)
                  
                    }

                    self.moveToMainTabBar()
                }
            }
        }
        
    }

    func setupGoogleLoginButton() {
        let button = UIButton(type: .system)
        
        LogoImage.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            LogoImage.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            LogoImage.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 200),
            LogoImage.widthAnchor.constraint(equalToConstant: 220),
            LogoImage.heightAnchor.constraint(equalToConstant: 220)
        ])

        button.backgroundColor = .black
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleGoogleSignIn), for: .touchUpInside)
        view.addSubview(button)

        // 🔹 구글 아이콘과 텍스트 설정
        let icon = UIImage(named: "google")?.withRenderingMode(.alwaysOriginal)
        let iconView = UIImageView(image: icon)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        // 아이콘의 크기 제약은 그대로 유지합니다.
        iconView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 20).isActive = true

        let label = UILabel()
        label.text = "Google로 로그인"
        label.textColor = .white
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false // ✅ 레이블은 터치 이벤트를 소비하지 않도록


        // 스택뷰 구성
        let stackView = UIStackView(arrangedSubviews: [iconView, label])
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.alignment = .center // 스택뷰 내부 아이템들의 수직 정렬
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.isUserInteractionEnabled = false // ✅ 스택뷰도 터치 이벤트를 소비하지 않도록

        // ✅ 스택뷰를 버튼의 서브뷰로 추가
        button.addSubview(stackView)
        
        // 버튼 자체의 이미지와 타이틀은 사용하지 않습니다.
        button.setImage(nil, for: .normal)
        button.setTitle(nil, for: .normal)

        NSLayoutConstraint.activate([
            // 버튼 자체의 위치 및 크기 제약 (기존과 동일)
            button.topAnchor.constraint(equalTo: LogoImage.bottomAnchor, constant: 80),
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.widthAnchor.constraint(equalToConstant: 250),
            button.heightAnchor.constraint(equalToConstant: 50),

            // ✅ 핵심: 스택뷰를 버튼의 중앙에 정렬
            stackView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
            // 스택뷰의 top/bottom/leading/trailing을 버튼에 맞추는 제약은 제거.
            // 이렇게 하면 스택뷰가 intrinsic content size를 유지하면서 버튼 중앙에 배치됩니다.
        ])
    }


    // ✅ 위에서 삭제한 자리에 이 새 함수를 붙여넣으세요.
    func moveToMainTabBar() {
        // 1. 현재 앱의 SceneDelegate를 가져옵니다.
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let sceneDelegate = windowScene.delegate as? SceneDelegate else {
            print("❌ SceneDelegate를 찾을 수 없습니다.")
            return
        }

        // 2. 스토리보드에서 TabBarController를 인스턴스화합니다.
        let storyboard = UIStoryboard(name: "Main", bundle: nil) // 스토리보드 파일 이름이 "Main"이 아니라면 수정해주세요.
        let tabBarController = storyboard.instantiateViewController(withIdentifier: "TabBarController")

        // 3. window의 rootViewController를 교체하여 화면을 전환합니다.
        sceneDelegate.window?.rootViewController = tabBarController

        // 4. 부드러운 전환 효과를 줍니다. (선택 사항)
        if let window = sceneDelegate.window {
            UIView.transition(with: window,
                              duration: 0.3,
                              options: .transitionCrossDissolve,
                              animations: nil,
                              completion: nil)
        }
    }
    func saveUserToFirestore(user: User) {
        let db = Firestore.firestore()
        
        let userData: [String: Any] = [
            "uid": user.uid,     //구글 아이디로 생성 되는 유저 아이디 값
            "email": user.email ?? "",
            "displayName": user.displayName ?? "",  //구글 아이디
            "photoURL": user.photoURL?.absoluteString ?? "",  //구글 포토 사진 값
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        db.collection("users").document(user.uid).setData(userData, merge: true) { error in
            if let error = error {
                print("❌ Firestore 저장 실패: \(error.localizedDescription)")
            } else {
                print("✅ Firestore에 사용자 정보 저장 완료")
            }
        }
    }
}
