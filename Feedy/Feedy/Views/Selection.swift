import Foundation
import SwiftData

enum SidebarSelection: Hashable {
    case all
    case feed(PersistentIdentifier)
}
