import UIKit

class TagCell: UICollectionViewCell {

    let iconView = UIImageView()
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        contentView.layer.cornerRadius = 8
        contentView.layer.masksToBounds = true
        updateAppearance(selected: false)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 14)

        contentView.addSubview(iconView)
        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func configure(with option: DiaryThemeOption, selected: Bool) {
        label.text = option.title
        iconView.image = UIImage(systemName: option.iconName)
        contentView.backgroundColor = selected ? .systemBlue : .systemGray5
        label.textColor = selected ? .white : .black
        iconView.tintColor = selected ? .white : .darkGray
    }


    func updateAppearance(selected: Bool) {
        contentView.backgroundColor = selected ? UIColor.systemBlue : UIColor.systemGray5
        label.textColor = selected ? .white : .black
        iconView.tintColor = selected ? .white : .darkGray
    }
}
