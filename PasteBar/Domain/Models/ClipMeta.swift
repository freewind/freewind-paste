import Foundation

struct ClipMeta: Codable, Equatable, Hashable {
  var textPreview: String?
  var languageGuess: String?

  var imageWidth: Int?
  var imageHeight: Int?
  var imageHash: String?

  var fileName: String?
  var fileSize: Int64?
  var fileExists: Bool?
  var fileModifiedAt: Date?
  var fileCount: Int?

  init(
    textPreview: String? = nil,
    languageGuess: String? = nil,
    imageWidth: Int? = nil,
    imageHeight: Int? = nil,
    imageHash: String? = nil,
    fileName: String? = nil,
    fileSize: Int64? = nil,
    fileExists: Bool? = nil,
    fileModifiedAt: Date? = nil,
    fileCount: Int? = nil
  ) {
    self.textPreview = textPreview
    self.languageGuess = languageGuess
    self.imageWidth = imageWidth
    self.imageHeight = imageHeight
    self.imageHash = imageHash
    self.fileName = fileName
    self.fileSize = fileSize
    self.fileExists = fileExists
    self.fileModifiedAt = fileModifiedAt
    self.fileCount = fileCount
  }
}
