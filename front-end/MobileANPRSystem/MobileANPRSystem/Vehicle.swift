import Foundation
import UIKit

class VehicleDetails {
    var regNumber: String = "Not yet received"
    var vehicleMake: String = ""
    var vehicleModel: String = ""
    var taxValid: Bool = false
    var motValid: Bool = false
    var manxVehicle: Bool = false
    var vehicleImage: UIImage?
    var systemEnabled: Bool = true

    func addDetails(jsonResponse: String) {
        guard let jsonData = jsonResponse.data(using: .utf8) else {
            print("Invalid JSON string")
            return
        }
        do {
            if let jsonDict = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                if let regValue = jsonDict["reg"] as? String, regValue.lowercased() == "data purged" {
                    systemEnabled = false
                    return
                }

                regNumber = jsonDict["reg"] as? String ?? regNumber
                if let make = jsonDict["make"] as? String {
                    vehicleMake = make.lowercased().split(separator: " ").map { $0.capitalized }.joined(separator: " ")
                }
                if let model = jsonDict["model"] as? String {
                    vehicleModel = model.lowercased().split(separator: " ").map { $0.capitalized }.joined(separator: " ")
                }
                taxValid = jsonDict["taxValid"] as? Bool ?? taxValid
                motValid = jsonDict["motValid"] as? Bool ?? motValid
                manxVehicle = jsonDict["manxVehicleMotExempt"] as? Bool ?? manxVehicle

                if let base64String = jsonDict["vehicleImage"] as? String,
                   let imageData = Data(base64Encoded: base64String) {
                    vehicleImage = UIImage(data: imageData)
                }

                systemEnabled = true
            }
        } catch {
            print("Error parsing JSON: \(error)")
        }
    }
}
