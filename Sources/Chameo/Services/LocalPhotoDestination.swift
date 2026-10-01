import Darwin
import Foundation

enum LocalPhotoDestination {
    static var defaultURL: URL? {
        // Sandbox home and search-path APIs may point into the container. Resolve
        // the account home without sharing getpwuid's mutable process-wide buffer.
        var account = passwd()
        var result: UnsafeMutablePointer<passwd>?
        var buffer = [CChar](repeating: 0, count: max(16_384, Int(sysconf(_SC_GETPW_R_SIZE_MAX))))
        return buffer.withUnsafeMutableBufferPointer { bytes in
            guard getpwuid_r(getuid(), &account, bytes.baseAddress, bytes.count, &result) == 0,
                  result != nil, let home = account.pw_dir else { return nil }
            return folder(in: URL(fileURLWithPath: String(cString: home), isDirectory: true),
                          distribution: AppDistribution.current)
        }
    }

    static func folder(in home: URL, distribution: AppDistributionConfiguration) -> URL {
        home.appendingPathComponent("Pictures", isDirectory: true)
            .appendingPathComponent(distribution.isTestBuild ? "Chameo (test)" : "Chameo", isDirectory: true)
    }
}
