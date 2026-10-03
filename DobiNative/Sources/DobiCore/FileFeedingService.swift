import Foundation

public struct TrashedFile {
    public let original: URL
    public let trash: URL
}
public struct FeedingFailure {
    public let file: URL
    public let message: String
}
public struct FileFeedingResult {
    public let trashed: [TrashedFile]
    public let failures: [FeedingFailure]
}
public struct FileFeedingService {
    public init() {}
    public func consume(_ files: [URL]) -> FileFeedingResult {
        let manager = FileManager.default
        var seen = Set<String>()
        let unique = files.filter { $0.isFileURL && seen.insert($0.path).inserted }
        let directories = unique.filter {
            let values = try? $0.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            return values?.isDirectory == true && values?.isSymbolicLink != true
        }
        let selected = unique.filter { url in
            !directories.contains { $0.path != url.path && url.path.hasPrefix($0.path + "/") }
        }
        var trashed: [TrashedFile] = [], failures: [FeedingFailure] = []
        for file in selected {
            let scoped = file.startAccessingSecurityScopedResource()
            defer { if scoped { file.stopAccessingSecurityScopedResource() } }
            do {
                var result: NSURL?
                try manager.trashItem(at: file, resultingItemURL: &result)
                guard let destination = result as URL? else {
                    throw NSError(domain: "DobiFeeding", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "无法确认废纸篓中的文件位置"])
                }
                trashed.append(TrashedFile(original: file, trash: destination))
            } catch { failures.append(FeedingFailure(file: file, message: error.localizedDescription)) }
        }
        return FileFeedingResult(trashed: trashed, failures: failures)
    }
}
