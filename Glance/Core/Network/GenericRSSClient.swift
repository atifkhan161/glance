import Foundation

struct GenericRSSClient: Sendable {
    func fetchArticles(from urlString: String) async throws -> [MMArticle] {
        guard let url = URL(string: urlString) else {
            throw GlanceError.networkError("Invalid RSS URL: \(urlString)")
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = GenericRSSParser()
        return parser.parse(data: data)
    }
}

private final class GenericRSSParser: NSObject, XMLParserDelegate {
    private var articles: [MMArticle] = []
    private var current: GenericRSSItem?
    private var textBuffer = ""

    func parse(data: Data) -> [MMArticle] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return Array(articles.prefix(20))
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        // Support both RSS <item> and Atom <entry>
        if elementName == "item" || elementName == "entry" {
            current = GenericRSSItem()
        }
        if elementName == "link", let href = attributeDict["href"] {
            current?.url = href
        }
        if elementName == "link", current?.url.isEmpty == true {
            // RSS <link> element with text content
            textBuffer = ""
            return
        }
        textBuffer = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard var item = current else { return }
        switch elementName {
        case "title":
            item.title = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        case "link":
            if item.url.isEmpty {
                item.url = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        case "published", "pubDate", "updated":
            item.published = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        case "author", "name" where item.author.isEmpty:
            item.author = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        case "category":
            item.category = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        case "description", "summary", "content", "content:encoded":
            item.content = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        case "item", "entry":
            let article = MMArticle(
                id: item.url.isEmpty ? UUID().uuidString : item.url,
                title: item.title,
                url: item.url,
                published: item.published,
                author: item.author,
                category: item.category,
                content: item.content
            )
            articles.append(article)
            current = nil
            return
        default: break
        }
        current = item
    }
}

private struct GenericRSSItem {
    var title = ""
    var url = ""
    var published = ""
    var author = ""
    var category = ""
    var content = ""
}
