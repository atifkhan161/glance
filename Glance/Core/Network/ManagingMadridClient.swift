import Foundation

protocol ManagingMadridClientProtocol: Sendable {
    func fetchArticles() async throws -> [MMArticle]
}

struct MMArticle: Codable, Sendable, Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let url: String
    let published: String
    let author: String
    let category: String
    let content: String
}

struct ManagingMadridClient: ManagingMadridClientProtocol, Sendable {
    func fetchArticles() async throws -> [MMArticle] {
        let url = URL(string: "https://www.managingmadrid.com/rss/index.xml")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = MMXMLParser()
        return parser.parse(data: data)
    }
}

private final class MMXMLParser: NSObject, XMLParserDelegate {
    private var articles: [MMArticle] = []
    private var current: MMXMLItem?
    private var textBuffer = ""

    func parse(data: Data) -> [MMArticle] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return Array(articles.prefix(10))
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "entry" { current = MMXMLItem() }
        if elementName == "link", let href = attributeDict["href"] { current?.url = href }
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
        case "title": item.title = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        case "published": item.published = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        case "name" where item.author.isEmpty: item.author = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        case "category": item.category = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        case "content": item.content = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
        case "entry":
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

private struct MMXMLItem {
    var title = ""
    var url = ""
    var published = ""
    var author = ""
    var category = ""
    var content = ""
}
