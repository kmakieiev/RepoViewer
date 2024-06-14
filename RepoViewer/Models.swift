import Foundation

struct Repository: Identifiable, Codable {
    let id: Int
    let name: String
    let description: String?
    let htmlUrl: String
    let createdAt: String
    let updatedAt: String
    var languages: String = "" // Provide a default empty string
    
    enum CodingKeys: String, CodingKey {
        case id, name, description
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Commit: Identifiable, Codable {
    var id: UUID = UUID()
    let sha: String
    let commit: CommitDetail
    
    var message: String {
        commit.message
    }
    
    var date: String {
        commit.author.date
    }
    
    enum CodingKeys: String, CodingKey {
        case sha, commit
    }
    
    struct CommitDetail: Codable {
        let author: Author
        let message: String
        
        struct Author: Codable {
            let date: String
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sha = try container.decode(String.self, forKey: .sha)
        commit = try container.decode(CommitDetail.self, forKey: .commit)
    }
}
