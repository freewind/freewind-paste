import Foundation

struct GroupedItems: Identifiable {
  let id: String
  let title: String
  let items: [ClipItem]
}
