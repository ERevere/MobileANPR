import XCTest
@testable import MobileANPRSystem

final class MobileANPRSystemTests: XCTestCase {

    func testVehicleDetailsParsing() throws {
        let json = """
        {
            "reg": "AB12CDE",
            "make": "FORD",
            "model": "FOCUS",
            "taxValid": true,
            "motValid": false,
            "manxVehicleMotExempt": true
        }
        """

        let vehicle = VehicleDetails()
        vehicle.addDetails(jsonResponse: json)

        XCTAssertEqual(vehicle.regNumber, "AB12CDE")
        XCTAssertEqual(vehicle.vehicleMake, "Ford")
        XCTAssertEqual(vehicle.vehicleModel, "Focus")
        XCTAssertTrue(vehicle.taxValid)
        XCTAssertFalse(vehicle.motValid)
        XCTAssertTrue(vehicle.manxVehicle)
        XCTAssertTrue(vehicle.systemEnabled)
    }

    func testVehicleDetailsDataPurged() throws {
        let json = """
        {
            "reg": "data purged"
        }
        """

        let vehicle = VehicleDetails()
        vehicle.addDetails(jsonResponse: json)

        XCTAssertFalse(vehicle.systemEnabled)
    }

    func testInvalidJSONIsHandled() throws {
        let json = """
        {
            "reg": 123,
            "make": true
        }
        """

        let vehicle = VehicleDetails()
        vehicle.addDetails(jsonResponse: json)

        XCTAssertEqual(vehicle.regNumber, "Not yet received")
        XCTAssertTrue(vehicle.systemEnabled)
    }

    func testInvalidImage() throws {
        let json = """
        {
            "reg": "test",
            "vehicleImage": "test"
        }
        """

        let vehicle = VehicleDetails()
        vehicle.addDetails(jsonResponse: json)

        XCTAssertNil(vehicle.vehicleImage)
    }

    func testWarningTrigger() throws {
        let vehicle = VehicleDetails()
        vehicle.taxValid = false
        vehicle.motValid = false
        vehicle.manxVehicle = false

        let reasons = buildInvalidReason(for: vehicle)
        XCTAssertTrue(reasons.contains("Tax expired"))
        XCTAssertTrue(reasons.contains("No MOT"))
    }

    func testExemptWarning() throws {
        let vehicle = VehicleDetails()
        vehicle.taxValid = false
        vehicle.motValid = false
        vehicle.manxVehicle = true

        let reasons = buildInvalidReason(for: vehicle)
        XCTAssertTrue(reasons.contains("Tax expired"))
        XCTAssertFalse(reasons.contains("No MOT"))
    }

    private func buildInvalidReason(for vehicle: VehicleDetails) -> String {
        var reasons: [String] = []
        if !vehicle.taxValid {
            reasons.append("Tax expired")
        }
        if !vehicle.motValid && !vehicle.manxVehicle {
            reasons.append("No MOT")
        }
        return reasons.joined(separator: " & ")
    }

    func testStoryboardVCLoads() async throws {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle(for: ViewController.self))
        guard let vc = storyboard.instantiateViewController(withIdentifier: "ViewController") as? ViewController else {
            XCTFail("failed to create ViewController from storyboard")
            return
        }

        await MainActor.run {
            vc.loadViewIfNeeded()
        }

        XCTAssertNotNil(vc.mainTextLabel)
        XCTAssertNotNil(vc.subTextLabel)
        XCTAssertNotNil(vc.additionalTextLabel)
    }
}
