import UIKit
import Foundation
import AVFoundation
import AVKit
import FLAnimatedImage

// testing
#if DEBUG
extension ViewController {
    func setTestVehicle(_ vehicle: VehicleDetails) {
        self.currentVehicle = vehicle
    }

    func getInvalidReasonForTest() -> String {
        return buildInvalidReason()
    }
}
#endif


protocol StatusUpdatable: AnyObject {
    func updateStatus(text: String, colour: UIColor, gifName: String)
}

final class VerifyConnection {
    private let serverURL = URL(string: "https://MobileANPR.local:5000/verify")!
    private let initialConnectionString: String
    private var currentConnectionString: String
    weak var delegate: StatusUpdatable?

    private var awaitingReset = false

    init(connectionString: String) {
        self.initialConnectionString = connectionString
        self.currentConnectionString = connectionString
    }

    func checkServerStatus(retryAfter delay: TimeInterval = 5.0) {
        guard !awaitingReset else {
            print("Delaying /verify call to allow server to reset code")
            return
        }

        var request = URLRequest(url: serverURL)
        request.timeoutInterval = 2
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if let error = error {
                    print("Connection failed: \(error.localizedDescription)")
                    self.delegate?.updateStatus(text: "System Inactive", colour: .yellow, gifName: "Cross")
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.checkServerStatus()
                    }
                    return
                }

                guard
                    let data = data,
                    let jsonResponse = try? JSONDecoder().decode([String: String].self, from: data),
                    let newConnectionString = jsonResponse["connection_string"]
                else {
                    self.delegate?.updateStatus(text: "Invalid Response", colour: .yellow, gifName: "Cross")
                    return
                }

                let components = newConnectionString.split(separator: ",")
                if components.count == 2, let oldKey = components.first, let newKey = components.last {
                    print(self.currentConnectionString)
                    print(String(oldKey))
                    if self.currentConnectionString == String(oldKey) {
                        self.currentConnectionString = String(newKey)
                        self.delegate?.updateStatus(text: "System Active", colour: .green, gifName: "Tick")
                        NotificationCenter.default.post(name: .didVerifyServer, object: nil)
                    } else {
                        self.awaitingReset = true
                        self.delegate?.updateStatus(text: "Terminated", colour: .systemTeal, gifName: "Cross")

                        DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
                            self.awaitingReset = false
                            self.currentConnectionString = self.initialConnectionString
                            self.checkServerStatus()
                        }
                    }
                }
            }
        }.resume()
    }
}



final class VehicleService {
    func fetchVehicleDetails(completion: @escaping (VehicleDetails?) -> Void) {
        guard let url = URL(string: "https://MobileANPR.local:5000/vehicle") else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard
                error == nil,
                let data = data,
                let jsonString = String(data: data, encoding: .utf8)
            else {
                print("error: \(error?.localizedDescription ?? "unknown")")
                completion(nil)
                return
            }

            let details = VehicleDetails()
            details.addDetails(jsonResponse: jsonString)
            completion(details)
        }.resume()
    }
}

class ViewController: UIViewController, StatusUpdatable {

    private var currentVehicle = VehicleDetails()
    private var rectangle: UIView = UIView()
    @IBOutlet weak var mainTextLabel: UILabel!
    @IBOutlet weak var subTextLabel: UILabel!
    @IBOutlet weak var additionalTextLabel: UILabel!
    private var soundPlayer: AVAudioPlayer!
    private var vehicleStatusColour: UIColor = .white
    private var previousColor: UIColor = .white

    private lazy var verifyConnection = VerifyConnection(connectionString: initialConnectionString)
    private let vehicleService = VehicleService()

    private let initialConnectionString = "LCbheVIz0uEnMjTaN9itil5eWnP0NCrJB3B8DxTvzXqigixEiS2iWSb0MNI4IpTlOXaRSQA2aQQfUMPCCDHlFCNrIyBS9F8FztLf"

    @IBOutlet weak var systemStatus: UILabel!
    @IBOutlet weak var vehicleUiImage: UIImageView!
    @IBOutlet weak var statusImage: FLAnimatedImageView!

    private var previousReg: String?
    private var warningCountForCurrentReg: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        verifyConnection.delegate = self
        setGifImage(from: "Loading")

        vehicleUiImage.frame = CGRect(x: 40, y: 90, width: 325, height: 160)
        vehicleUiImage.contentMode = .scaleAspectFit
        view.addSubview(vehicleUiImage)

        if let mainLabel = mainTextLabel,
           let subLabel = subTextLabel,
           let additionalLabel = additionalTextLabel {

            mainLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 48, weight: .bold)
            subLabel.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
            additionalLabel.font = UIFont.systemFont(ofSize: 24, weight: .regular)

            for label in [mainLabel, subLabel, additionalLabel] {
                label.textColor = UIColor.black
                label.textAlignment = .center
                label.adjustsFontSizeToFitWidth = true
                label.minimumScaleFactor = 0.5
                label.lineBreakMode = .byClipping
                label.baselineAdjustment = .alignCenters
                label.numberOfLines = 1
                label.center.x = rectangle.center.x
                label.sizeToFit()
                label.clipsToBounds = false
                label.isAccessibilityElement = true
            }
        }

        view.addSubview(rectangle)
        view.addSubview(mainTextLabel)
        view.addSubview(subTextLabel)
        view.addSubview(additionalTextLabel)

        NotificationCenter.default.addObserver(self, selector: #selector(loadVehicleData), name: .didVerifyServer, object: nil)

        verifyConnection.checkServerStatus()
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.verifyConnection.checkServerStatus()
        }
    }

    @objc private func loadVehicleData() {
        previousColor = vehicleStatusColour

        vehicleService.fetchVehicleDetails { [weak self] details in
            guard let self = self, let details = details else { return }

            DispatchQueue.main.async {
                self.currentVehicle = details
                self.updateLabels()
            }
        }
    }

    func updateStatus(text: String, colour: UIColor, gifName: String) {
        systemStatus.text = text
        setGifImage(from: gifName)

        if text == "Terminated" {
            mainTextLabel.text = "Terminated"
            subTextLabel.text = "Authentication Failed"
            additionalTextLabel.text = "Retrying..."
            let customTeal = UIColor(red: 1, green: 0.859, blue: 0.557, alpha: 1.0)
            updateBoxColour(newColour: customTeal)
            vehicleStatusColour = customTeal
            vehicleUiImage.image = nil
            positionRectangleAndLabels(offsetY: 150)
        } else if text == "System Inactive" {
            mainTextLabel.text = "Disconnected"
            subTextLabel.text = "System failed to connect"
            additionalTextLabel.text = "Retrying..."
            let customYellow = UIColor(red: 1, green: 0.859, blue: 0.557, alpha: 1.0)
            updateBoxColour(newColour: customYellow)
            vehicleStatusColour = customYellow
            vehicleUiImage.image = nil
            positionRectangleAndLabels(offsetY: 150)
        }
    }

    private func updateLabels() {
        let isSystemInactive = !currentVehicle.systemEnabled
        let hasTax = currentVehicle.taxValid
        let hasMOT = currentVehicle.motValid
        let isExempt = currentVehicle.manxVehicle
        let motIsEffectivelyValid = hasMOT || isExempt
        let reg = currentVehicle.regNumber.lowercased()
        let noPlateYet = reg.contains("not") && reg.contains("receiv")

        var mainText = ""
        var subText = ""
        var additionalText = ""
        var newColour: UIColor = .white

        let offsetY: CGFloat = (hasTax && motIsEffectivelyValid) ? 150 : 500
        positionRectangleAndLabels(offsetY: offsetY)

        if noPlateYet {
            mainText = "No vehicle detected"
            subText = "Awaiting first plate"
            additionalText = ""
            newColour = UIColor(red: 0.557, green: 0.631, blue: 1, alpha: 1.0)
            vehicleUiImage.image = nil
            positionRectangleAndLabels(offsetY: 150)
        } else if isSystemInactive {
            mainText = "System Disconnected"
            subText = "System failed to connect"
            additionalText = "Retrying..."
            newColour = UIColor(red: 1, green: 0.859, blue: 0.557, alpha: 1.0)
        } else if hasTax && motIsEffectivelyValid {
            mainText = currentVehicle.regNumber
            subText = "\(currentVehicle.vehicleMake) \(currentVehicle.vehicleModel)"
            additionalText = ""
            newColour = UIColor(red: 0.698, green: 1, blue: 0.557, alpha: 1.0)
        } else {
            mainText = currentVehicle.regNumber
            subText = buildInvalidReason()
            additionalText = "\(currentVehicle.vehicleMake) \(currentVehicle.vehicleModel)"
            newColour = .red
        }

        let labelData: [(UILabel, String)] = [
            (mainTextLabel, mainText),
            (subTextLabel, subText),
            (additionalTextLabel, additionalText)
        ]

        for (label, text) in labelData {
            label.text = text
            label.accessibilityLabel = text
        }


        updateBoxColour(newColour: newColour)
        vehicleStatusColour = newColour
        
        if newColour == .red {
            if reg != previousReg {
                previousReg = reg
                warningCountForCurrentReg = 1
                warnUserVisuals()
                warnUserAudio()
            } else if warningCountForCurrentReg < 2 {
                warningCountForCurrentReg += 1
                warnUserVisuals()
                warnUserAudio()
            }

            if let image = currentVehicle.vehicleImage {
                vehicleUiImage.image = image
            }
        } else {
            vehicleUiImage.image = nil
            previousReg = nil
            warningCountForCurrentReg = 0
        }
    }

    private func buildInvalidReason() -> String {
        var reasons: [String] = []
        if !currentVehicle.taxValid {
            reasons.append("Tax expired")
        }
        if !currentVehicle.motValid && !currentVehicle.manxVehicle {
            reasons.append("No MOT")
        }
        return reasons.joined(separator: " & ")
    }

    private func warnUserAudio() {
        if let fileLocation = Bundle.main.url(forResource: "warnUser", withExtension: "mp3") {
            soundPlayer = try? AVAudioPlayer(contentsOf: fileLocation)
            soundPlayer?.play()
        }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    private func warnUserVisuals() {
        UIView.animate(withDuration: 0.25, animations: {
            self.view.backgroundColor = .red
        }) { _ in
            UIView.animate(withDuration: 0.25, animations: {
                self.view.backgroundColor = .white
            }) { _ in
                self.view.backgroundColor = .white
            }
        }
    }

    private func updateBoxColour(newColour: UIColor) {
        rectangle.backgroundColor = newColour
    }

    private func setGifImage(from resourceName: String) {
        guard let gifURL = Bundle.main.url(forResource: resourceName, withExtension: "gif"),
              let gifData = try? Data(contentsOf: gifURL) else {
            statusImage.animatedImage = nil
            return
        }
        statusImage.animatedImage = FLAnimatedImage(gifData: gifData)
    }

    private func positionRectangleAndLabels(offsetY: CGFloat) {
        let screenWidth = view.bounds.width
        let rectangleWidth: CGFloat = 325
        let rectangleX = (screenWidth - rectangleWidth) / 2

        rectangle.frame = CGRect(x: rectangleX, y: offsetY, width: rectangleWidth, height: 200)
        rectangle.layer.cornerRadius = 10
        rectangle.layer.borderWidth = 0
        rectangle.layer.borderColor = UIColor.black.cgColor

        let mainLabelHeight: CGFloat = 100
        let subLabelHeight: CGFloat = 40
        let additionalLabelHeight: CGFloat = 35

        let totalHeight = mainLabelHeight + subLabelHeight + additionalLabelHeight
        let spacing = (rectangle.frame.height - totalHeight) / 4

        mainTextLabel.frame = CGRect(x: rectangleX, y: offsetY + spacing + 30, width: rectangleWidth, height: mainLabelHeight)
        subTextLabel.frame = CGRect(x: rectangleX, y: offsetY + spacing * 2 + mainLabelHeight, width: rectangleWidth, height: subLabelHeight)
        additionalTextLabel.frame = CGRect(x: rectangleX, y: offsetY + spacing * 10 + mainLabelHeight + subLabelHeight, width: rectangleWidth, height: additionalLabelHeight)

        for label in [mainTextLabel, subTextLabel, additionalTextLabel] {
            label?.textAlignment = .center
        }
    }
}

extension Notification.Name {
    static let didVerifyServer = Notification.Name("didVerifyServer")
}
