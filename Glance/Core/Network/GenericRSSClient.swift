import Foundation

struct RSSFeedInfo: Sendable {
    let title: String
    let articles: [MMArticle]
}

struct GenericRSSClient: Sendable {
    func fetchArticles(from urlString: String) async throws -> [MMArticle] {
        guard let url = URL(string: urlString) else {
            throw GlanceError.networkError("Invalid RSS URL: \(urlString)")
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = GenericRSSParser()
        return parser.parse(data: data)
    }

    func fetchFeedInfo(from urlString: String) async throws -> RSSFeedInfo {
        guard let url = URL(string: urlString) else {
            throw GlanceError.networkError("Invalid RSS URL: \(urlString)")
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = GenericRSSParser()
        let (title, articles) = parser.parseWithFeedTitle(data: data)
        return RSSFeedInfo(title: title, articles: articles)
    }
}

private final class GenericRSSParser: NSObject, XMLParserDelegate {
    private var articles: [MMArticle] = []
    private var current: GenericRSSItem?
    private var textBuffer = ""
    private var feedTitle = ""
    private var inFeedTitle = false
    private var depth = 0

    func parse(data: Data) -> [MMArticle] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return Array(articles.prefix(20))
    }

    func parseWithFeedTitle(data: Data) -> (String, [MMArticle]) {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return (feedTitle, Array(articles.prefix(20)))
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "item" || elementName == "entry" {
            current = GenericRSSItem()
        }
        if elementName == "link", let href = attributeDict["href"] {
            current?.url = href
        }
        if elementName == "link", current?.url.isEmpty == true {
            textBuffer = ""
            return
        }
        if elementName == "title" && current == nil {
            inFeedTitle = true
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
        if elementName == "title" && inFeedTitle {
            let trimmed = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && feedTitle.isEmpty {
                feedTitle = trimmed
            }
            inFeedTitle = false
        }

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
                content: item.content,
                scrapedContent: ""
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
    var scrapedContent = ""
}
