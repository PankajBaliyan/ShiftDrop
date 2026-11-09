import Foundation

// Recipes: every wheel slice is a small JSON recipe (same format as the Windows app, docs/recipes.md).
// The built-ins below are the image and file ones from src/RecipeStore.cpp; "icon" is an SF Symbol name here
// (the Windows recipes carry a Segoe Fluent code point instead). Video, audio, PDF and document recipes come later.

struct Step {
    var action: String
    var params: [String: Any]
    func int(_ key: String, _ fallback: Int) -> Int { (params[key] as? Int) ?? fallback }
    func string(_ key: String, _ fallback: String) -> String { (params[key] as? String) ?? fallback }
}

struct Recipe {
    var id: String
    var label: String
    var detail: String
    var ring: String        // convert, tools, reduce, files
    var suffix: String
    var icon: String?
    var steps: [Step]
}

enum RecipeStore {
    static let all: [Recipe] = {
        var list = parse(builtIn)
        for smaller in stride(from: 90, through: 20, by: -10) {
            list.append(Recipe(id: "reduce-image-\(smaller)", label: "\u{2212}\(smaller)%", detail: "\(smaller)% smaller", ring: "reduce", suffix: "reduced",
                               icon: nil, steps: [Step(action: "image.compress", params: ["percent": 100 - smaller])]))
        }
        for f in Media.formats {
            list.append(Recipe(id: "to-\(f.id)", label: f.label, detail: f.detail, ring: "convert", suffix: "converted", icon: nil,
                               steps: [Step(action: "media.convert", params: ["format": f.id])]))
        }
        for smaller in stride(from: 90, through: 20, by: -10) {
            list.append(Recipe(id: "reduce-media-\(smaller)", label: "\u{2212}\(smaller)%", detail: "\(smaller)% smaller", ring: "reduce", suffix: "reduced",
                               icon: nil, steps: [Step(action: "media.compress", params: ["percent": 100 - smaller])]))
        }
        list += documentRecipes()
        return list
    }()

    private static func r(_ id: String, _ label: String, _ detail: String, ring: String = "convert", suffix: String = "converted", icon: String? = nil,
                          action: String, _ params: [String: Any] = [:]) -> Recipe {
        Recipe(id: id, label: label, detail: detail, ring: ring, suffix: suffix, icon: icon, steps: [Step(action: action, params: params)])
    }

    /// PDF, documents, subtitles, sheets and archives (ids and descriptions as in the Windows recipes).
    private static func documentRecipes() -> [Recipe] {
        var l: [Recipe] = []
        // PDF
        l.append(r("pdf-to-jpg", "JPG", "Pages as JPEG, 300 dpi", icon: "photo", action: "pdf.to_images", ["format": "jpg"]))
        l.append(r("pdf-to-png", "PNG", "Pages as PNG, 300 dpi", icon: "photo", action: "pdf.to_images", ["format": "png"]))
        l.append(r("pdf-to-txt", "TXT", "Text extracted with OCR", icon: "doc.plaintext", action: "pdf.to_text"))
        l.append(r("pdf-to-md", "MD", "Markdown with headings", icon: "number", action: "pdf.to_markdown"))
        l.append(r("pdf-to-docx", "DOCX", "Word doc from text", icon: "doc.text", action: "pdf.to_docx"))
        l.append(r("pdf-to-epub", "EPUB", "E-book from text", icon: "book", action: "pdf.to_epub"))
        l.append(r("pdf-to-html", "HTML", "Web page from text", icon: "chevron.left.forwardslash.chevron.right", action: "pdf.to_html"))
        l.append(r("images-to-pdf", "PDF", "One PDF from images", icon: "doc.richtext", action: "images.to_pdf"))
        l.append(r("pdf-merge", "Merge", "Merge into one PDF", ring: "tools", suffix: "merged", icon: "rectangle.stack", action: "pdf.merge"))
        l.append(r("pdf-compress", "Compress", "Smaller PDF, screen res", ring: "tools", suffix: "compressed", icon: nil, action: "pdf.compress"))
        l.append(r("ocr-copy-text", "Copy text", "Extract & copy text", ring: "tools", suffix: "text", icon: "text.viewfinder", action: "ocr.copy_text"))
        for smaller in stride(from: 90, through: 20, by: -10) {
            l.append(r("reduce-pdf-\(smaller)", "\u{2212}\(smaller)%", "\(smaller)% smaller PDF", ring: "reduce", suffix: "reduced", action: "pdf.compress", ["percent": 100 - smaller]))
        }
        // Documents
        for (id, label, detail, icon) in [("docx", "DOCX", "Word document", "doc.text"), ("pdf", "PDF", "PDF, A4 or Letter", "doc.richtext"),
                                           ("md", "MD", "Markdown text", "number"), ("html", "HTML", "A web page", "chevron.left.forwardslash.chevron.right"),
                                           ("epub", "EPUB", "E-book format", "book"), ("txt", "TXT", "Plain text", "doc.plaintext")] {
            l.append(r("docs-to-\(id)", label, detail, icon: icon, action: "docs.convert", ["format": id]))
        }
        // Subtitles and sheets
        for (id, label, detail) in [("srt", "SRT", "SubRip subtitles"), ("vtt", "VTT", "WebVTT subtitles"), ("txt", "TXT", "Plain text subtitles")] {
            l.append(r("subs-to-\(id)", label, detail, icon: "captions.bubble", action: "subs.convert", ["format": id]))
        }
        l.append(r("sheets-to-csv", "CSV", "Comma-separated values", icon: "tablecells", action: "sheets.convert", ["format": "csv"]))
        l.append(r("sheets-to-tsv", "TSV", "Tab-separated values", icon: "tablecells", action: "sheets.convert", ["format": "tsv"]))
        // Archives and folders
        l.append(r("archive-extract", "Extract", "Unpack into folder", suffix: "extracted", icon: "shippingbox", action: "archive.extract"))
        for (id, label, detail) in [("zip", "ZIP", "Repack as ZIP"), ("targz", "TAR.GZ", "Repack as TAR.GZ"), ("7z", "7z", "Repack as 7z")] {
            l.append(r("archive-to-\(id)", label, detail, icon: "archivebox", action: "archive.repack", ["format": id]))
        }
        for (id, label, detail, suffix) in [("zip", "ZIP", "Pack into one ZIP", "zipped"), ("targz", "TAR.GZ", "Pack into one TAR.GZ", "archived"), ("7z", "7z", "Pack into one 7z", "archived")] {
            l.append(r("archive-folder-\(id)", label, detail, suffix: suffix, icon: "archivebox", action: "archive.pack_folder", ["format": id]))
        }
        l.append(r("archive-zip", "Zip", "Zip into one file", ring: "files", suffix: "zipped", icon: "archivebox", action: "archive.zip"))
        return l
    }

    static func find(_ id: String) -> Recipe? { all.first { $0.id == id } }

    /// User recipes: ~/Library/Application Support/ShiftDrop/recipes/*.json (same id replaces a built-in).
    static var userFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ShiftDrop/recipes")
    }

    static func loadUser() -> [Recipe] {
        let files = (try? FileManager.default.contentsOfDirectory(at: userFolder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }.flatMap { url -> [Recipe] in
            guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else { return [] }
            return parse(stripComments(text))
        }
    }

    private static func stripComments(_ s: String) -> String {
        s.split(separator: "\n", omittingEmptySubsequences: false).filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }.joined(separator: "\n")
    }

    static func parse(_ text: String) -> [Recipe] {
        guard let data = text.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) else { return [] }
        let items = (json as? [[String: Any]]) ?? ((json as? [String: Any]).map { [$0] } ?? [])
        return items.compactMap { d in
            guard let id = d["id"] as? String, let label = d["label"] as? String, let steps = d["steps"] as? [[String: Any]], !steps.isEmpty else { return nil }
            return Recipe(id: id, label: label, detail: (d["description"] as? String) ?? label, ring: (d["ring"] as? String) ?? "convert",
                          suffix: (d["suffix"] as? String) ?? "converted", icon: d["icon"] as? String,
                          steps: steps.compactMap { s in (s["action"] as? String).map { Step(action: $0, params: (s["params"] as? [String: Any]) ?? [:]) } })
        }
    }

    private static let builtIn = #"""
    [
      { "id": "to-png",  "label": "PNG",  "description": "PNG, lossless",  "steps": [ { "action": "image.encode", "params": { "format": "png" } } ] },
      { "id": "to-jpg",  "label": "JPG",  "description": "JPEG, quality 92",  "steps": [ { "action": "image.encode", "params": { "format": "jpg", "quality": 92 } } ] },
      { "id": "to-webp", "label": "WebP", "description": "WebP, quality 85", "steps": [ { "action": "image.encode", "params": { "format": "webp", "quality": 85 } } ] },
      { "id": "to-avif", "label": "AVIF", "description": "AVIF, quality 60", "steps": [ { "action": "image.encode", "params": { "format": "avif", "quality": 60 } } ] },
      { "id": "to-heic", "label": "HEIC", "description": "HEIC, quality 80", "steps": [ { "action": "image.encode", "params": { "format": "heic", "quality": 80 } } ] },
      { "id": "to-tiff", "label": "TIFF", "description": "TIFF, lossless", "steps": [ { "action": "image.encode", "params": { "format": "tiff" } } ] },
      { "id": "to-bmp",  "label": "BMP",  "description": "Bitmap, uncompressed",  "steps": [ { "action": "image.encode", "params": { "format": "bmp" } } ] },

      { "id": "rotate-right", "label": "Rotate right", "description": "Rotate 90° clockwise", "ring": "tools", "suffix": "edited", "icon": "rotate.right",
        "steps": [ { "action": "image.rotate", "params": { "degrees": "90" } }, { "action": "image.encode", "params": { "format": "same" } } ] },
      { "id": "max-1920", "label": "1920 px", "description": "Fit within 1920 px", "ring": "tools", "suffix": "edited",
        "steps": [ { "action": "image.resize", "params": { "maxEdge": 1920 } }, { "action": "image.encode", "params": { "format": "same" } } ] },
      { "id": "flip", "label": "Flip", "description": "Mirror left to right", "ring": "tools", "suffix": "edited",
        "steps": [ { "action": "image.flip", "params": { "axis": "horizontal" } }, { "action": "image.encode", "params": { "format": "same" } } ] },
      { "id": "half-size", "label": "50%", "description": "Half width & height", "ring": "tools", "suffix": "edited",
        "steps": [ { "action": "image.scale", "params": { "percent": 50 } }, { "action": "image.encode", "params": { "format": "same" } } ] },
      { "id": "rotate-left", "label": "Rotate left", "description": "Rotate 90° left", "ring": "tools", "suffix": "edited", "icon": "rotate.left",
        "steps": [ { "action": "image.rotate", "params": { "degrees": "270" } }, { "action": "image.encode", "params": { "format": "same" } } ] },
      { "id": "max-1080", "label": "1080 px", "description": "Fit within 1080 px", "ring": "tools", "suffix": "edited",
        "steps": [ { "action": "image.resize", "params": { "maxEdge": 1080 } }, { "action": "image.encode", "params": { "format": "same" } } ] },
      { "id": "compress-image", "label": "Compress", "description": "Smaller JPEG, quality 75", "ring": "tools", "suffix": "compressed",
        "steps": [ { "action": "image.compress", "params": { "quality": 75 } } ] },
      { "id": "image-under-1mb", "label": "Under 1 MB", "description": "Best quality under 1 MB", "ring": "tools", "suffix": "compressed",
        "steps": [ { "action": "image.compress", "params": { "maxKB": 1024 } } ] },

      { "id": "compress-media", "label": "Compress", "description": "H.264 + AAC, up to 1080p", "ring": "tools", "suffix": "compressed",
        "steps": [ { "action": "media.compress", "params": { "maxHeight": 1080 } } ] },
      { "id": "media-half", "label": "50% size", "description": "Half the file size", "ring": "tools", "suffix": "compressed",
        "steps": [ { "action": "media.compress", "params": { "percent": 50 } } ] },
      { "id": "media-under-10mb", "label": "Under 1 MB", "description": "Fits in 10 MB, for chat", "ring": "tools", "suffix": "compressed",
        "steps": [ { "action": "media.compress", "params": { "targetMB": 10 } } ] },
      { "id": "media-under-25mb", "label": "Under 25 MB", "description": "Fits in 25 MB, for email", "ring": "tools", "suffix": "compressed",
        "steps": [ { "action": "media.compress", "params": { "targetMB": 25 } } ] },

      { "id": "float",     "label": "Float",     "description": "Hold on Float shelf", "ring": "files", "icon": "tray.and.arrow.down", "steps": [ { "action": "file.float" } ] },
      { "id": "copy",      "label": "Copy",      "description": "Copy to clipboard", "ring": "files", "icon": "doc.on.doc", "steps": [ { "action": "file.copy" } ] },
      { "id": "move",      "label": "Move to folder", "description": "Move to picked folder", "ring": "files", "icon": "folder", "steps": [ { "action": "file.move" } ] },
      { "id": "copy-path", "label": "Copy path", "description": "Copy full path", "ring": "files", "icon": "link", "steps": [ { "action": "file.copy_path" } ] },
      { "id": "terminal",  "label": "Terminal",  "description": "Open terminal here", "ring": "files", "icon": "terminal", "steps": [ { "action": "file.terminal" } ] },
      { "id": "duplicate", "label": "Duplicate", "description": "Make copy next to it", "ring": "files", "suffix": "copy", "icon": "plus.square.on.square", "steps": [ { "action": "file.duplicate" } ] },
      { "id": "reveal",    "label": "Show in Finder", "description": "Reveal in Finder", "ring": "files", "icon": "magnifyingglass", "steps": [ { "action": "file.reveal" } ] }
    ]
    """#
}
