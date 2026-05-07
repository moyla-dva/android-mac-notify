import Foundation

enum NetworkAddressResolver {
    static func preferredIPv4Address() -> String? {
        var candidates: [(priority: Int, name: String, address: String)] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }

        defer { freeifaddrs(ifaddr) }

        for pointer in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & IFF_UP) == IFF_UP
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK

            guard isUp, !isLoopback else {
                continue
            }

            guard let addr = interface.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else {
                continue
            }

            let name = String(cString: interface.ifa_name)
            guard let priority = interfacePriority(for: name) else {
                continue
            }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(
                addr,
                socklen_t(addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )

            let candidateBytes = hostname.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
            let candidate = String(decoding: candidateBytes, as: UTF8.self)
            if !candidate.isEmpty, !candidate.hasPrefix("169.254.") {
                candidates.append((priority: priority, name: name, address: candidate))
            }
        }

        return candidates
            .sorted {
                if $0.priority == $1.priority {
                    return $0.name < $1.name
                }
                return $0.priority < $1.priority
            }
            .first?
            .address
    }

    private static func interfacePriority(for name: String) -> Int? {
        if name == "en0" {
            return 0
        }
        if name.hasPrefix("en") {
            return 1
        }
        if name.hasPrefix("bridge") {
            return 2
        }
        return nil
    }
}
