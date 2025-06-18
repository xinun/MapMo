// TodayDiaryCell.swift 파일 내
import UIKit

class TodayDiaryCell: UICollectionViewCell {
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        // ✅ 배경색, 코너, 그림자 설정 추가
        setupCellAppearance() // 새로운 함수 호출
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupCellAppearance() {
        backgroundColor = UIColor(red: 88/255, green: 86/255, blue: 214/255, alpha: 0.1) // Soft Indigo 10% alpha

        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8

        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true
    }

    private func setupViews() {
        titleLabel.font = .boldSystemFont(ofSize: 16)
        titleLabel.textColor = .label // 다크 모드 고려
        
        dateLabel.font = .systemFont(ofSize: 13)
        dateLabel.textColor = .secondaryLabel // 다크 모드 고려

        let stack = UIStackView(arrangedSubviews: [titleLabel, dateLabel])
        stack.axis = .vertical
        stack.spacing = 4
        contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    func configure(with diary: Diary) {
        titleLabel.text = diary.title
        dateLabel.text = diary.formattedDate
    }
}
