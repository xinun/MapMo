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
                        self.moveToMainTabBar()
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

    func moveToMainTabBar() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let tabBarVC = storyboard.instantiateViewController(withIdentifier: "TabBarController") as? UITabBarController {
            tabBarVC.modalPresentationStyle = .fullScreen
            self.present(tabBarVC, animated: true)
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
