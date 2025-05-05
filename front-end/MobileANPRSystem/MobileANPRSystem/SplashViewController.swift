import UIKit
import AVKit
import AVFoundation

class SplashViewController: UIViewController {

    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?
    let logoImageView = UIImageView()

    override func viewDidLoad() {
        super.viewDidLoad()

        playVideo()

        setupLogo()
    }

    private func playVideo() {
        guard let path = Bundle.main.path(forResource: "BGVideo", ofType: "mp4") else {
            print("Video not found")
            transitionToMainUI()
            return
        }

        let player = AVPlayer(url: URL(fileURLWithPath: path))
        self.player = player

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = self.view.bounds
        playerLayer.videoGravity = .resizeAspectFill
        self.view.layer.addSublayer(playerLayer)

        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)

        player.play()
    }

    private func setupLogo() {
        logoImageView.image = UIImage(named: "Logo.png")
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(logoImageView)

        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 650),
            logoImageView.heightAnchor.constraint(equalToConstant: 380)
        ])
    }

    @objc func playerDidFinishPlaying(note: NSNotification) {

        UIView.animate(withDuration: 0.5, animations: {
            self.view.layer.sublayers?.first?.opacity = 0
            self.logoImageView.alpha = 0
        }) { _ in

            self.transitionToMainUI()
        }
    }

    private func transitionToMainUI() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let mainViewController = storyboard.instantiateViewController(withIdentifier: "ViewController") as? ViewController {
            mainViewController.modalTransitionStyle = .crossDissolve
            mainViewController.modalPresentationStyle = .fullScreen
            self.present(mainViewController, animated: true, completion: nil)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
