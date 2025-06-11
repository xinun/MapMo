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
        button.setTitle("Google로 로그인", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .red
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleGoogleSignIn), for: .touchUpInside)
        view.addSubview(button)
        button.isUserInteractionEnabled = true

        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 250),
            button.heightAnchor.constraint(equalToConstant: 50)
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
