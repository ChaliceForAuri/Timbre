import AppKit

/// A deep copy of a pasteboard's contents — every item, every representation.
///
/// Skipping the save/restore dance is a small betrayal users notice
/// immediately: dictating should not eat whatever they had copied.
struct PasteboardSnapshot {

    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(capturing pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            var contents = [NSPasteboard.PasteboardType: Data]()
            for type in item.types {
                contents[type] = item.data(forType: type)
            }
            return contents
        }
    }

    var isEmpty: Bool {
        items.isEmpty
    }

    /// Replaces the pasteboard's contents with the snapshot, all items in one
    /// write so multi-item clipboards survive intact.
    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }

        let restored = items.map { contents in
            let item = NSPasteboardItem()
            for (type, data) in contents {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(restored)
    }
}
