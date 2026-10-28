
import Foundation
import Network

final class APINetworkInfo {

    static let shared = APINetworkInfo()

    private let monitor = NWPathMonitor()

    private let queue = DispatchQueue(
        label: "com.apiobservability.network",
        qos: .utility
    )

    private var currentPath: NWPath?

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.currentPath = path
        }

        monitor.start(queue: queue)
    }

    var networkType: String {
        guard let path = currentPath else {
            return "Unknown"
        }

        guard path.status == .satisfied else {
            return "No Internet"
        }

        if path.usesInterfaceType(.wifi) {
            return "WiFi"
        }

        if path.usesInterfaceType(.cellular) {
            return "Cellular"
        }

        if path.usesInterfaceType(.wiredEthernet) {
            return "Ethernet"
        }

        return "Other"
    }
}

