# GitHub Repo Viewer for macOS

A simple macOS application built with Swift and SwiftUI that allows users to fetch and display information about GitHub repositories. Users can enter a GitHub username to get a list of repositories associated with that account. For each selected repository, the app displays detailed information and a list of commits.

## Features

- Fetch a list of repositories for a specified GitHub user
- Display repository details including name, description, URL, creation date, last update date, and languages used
- View the list of commits for a selected repository with commit date, hash, and message
- Notification support to inform the user when repositories are successfully fetched

## Requirements

- macOS 10.15 or later
- Xcode 12 or later

## Installation

1. Clone the repository:
    ```bash
    git clone https://github.com/kmakieiev/RepoViewer.git
    cd RepoViewer
    ```

2. Open the project in Xcode:
    ```bash
    open RepoViewer.xcodeproj
    ```

3. Build and run the project.

## Usage

1. Launch the application.
2. Enter a GitHub username in the text field and click "Fetch Repos".
3. A list of repositories will be displayed. Click on a repository to view its details and commits.

## Project Structure

- `ContentView.swift`: Main SwiftUI view handling user input and displaying repositories and commits.
- `Models.swift`: Defines the data models for repositories and commits.
- `GitHubService.swift`: Contains functions to fetch repositories, commits, and languages from the GitHub API.

## Code Overview

### `ContentView.swift`

Handles the user interface and interactions.

```swift
import SwiftUI
import UserNotifications

struct ContentView: View {
    @State private var username: String = ""
    @State private var repositories: [Repository] = []
    @State private var selectedRepository: Repository?
    @State private var commits: [Commit] = []

    var body: some View {
        VStack {
            HStack {
                TextField("Enter GitHub username", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Fetch Repos") {
                    fetchRepositories(for: username) { repos in
                        self.repositories = repos
                        self.showNotification(message: "User \(username) found. The list of repositories has been successfully fetched.")
                    }
                }
            }
            .padding()

            List(repositories, id: \.id) { repo in
                VStack(alignment: .leading) {
                    Text(repo.name).font(.headline)
                    Text(repo.description ?? "No description")
                    Text(repo.htmlUrl).foregroundColor(.blue)
                    Text("Created: \(repo.createdAt)")
                    Text("Last updated: \(repo.updatedAt)")
                    Text("Languages: \(repo.languages)")
                }
                .onTapGesture {
                    selectedRepository = repo
                    fetchCommits(for: repo, username: username) { commits in
                        self.commits = commits
                    }
                    
                    var mutableRepo = repo // Create a mutable copy
                    fetchLanguages(for: mutableRepo, username: username) { languages in
                        mutableRepo.languages = languages
                        DispatchQueue.main.async {
                            // Update the original repo in the UI thread
                            if let index = repositories.firstIndex(where: { $0.id == repo.id }) {
                                repositories[index] = mutableRepo
                            }
                        }
                    }
                }
            }

            if let selectedRepo = selectedRepository {
                Text("Commits for \(selectedRepo.name)").font(.headline)
                List(commits, id: \.sha) { commit in
                    VStack(alignment: .leading) {
                        Text(commit.date)
                        Text(commit.sha)
                        Text(commit.message)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if granted {
                    print("Notification authorization granted")
                } else {
                    print("Notification authorization denied")
                }
            }
        }
    }
    
    private func showNotification(message: String) {
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = "GitHub Repositories"
        notificationContent.body = message
        notificationContent.sound = UNNotificationSound.default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "GitHubNotification", content: notificationContent, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error displaying notification: \(error.localizedDescription)")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
```

### `Models.swift`

Defines the data models for repositories and commits.

```swift
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
```

### `GiHubService.swift`

Contains functions to fetch repositories, commits, and languages from the GitHub API.

```swift
import Foundation

func fetchRepositories(for username: String, completion: @escaping ([Repository]) -> Void) {
    guard let url = URL(string: "https://api.github.com/users/\(username)/repos") else {
        print("Invalid URL")
        return
    }
    
    URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            print("Network error: \(error.localizedDescription)")
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Invalid response")
            return
        }
        
        print("Response status code: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 401 {
            print("Unauthorized: Check your personal access token")
            return
        }
        
        guard httpResponse.statusCode == 200 else {
            print("Invalid response or status code not 200: \(httpResponse.statusCode)")
            return
        }
        
        guard let data = data else {
            print("No data received")
            return
        }
        
        do {
            var repositories = try JSONDecoder().decode([Repository].self, from: data)
            
            // Fetch languages for each repository
            let dispatchGroup = DispatchGroup()
            
            for index in repositories.indices {
                dispatchGroup.enter()
                fetchLanguages(for: repositories[index], username: username) { languages in
                    repositories[index].languages = languages
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                DispatchQueue.main.async {
                    completion(repositories)
                }
            }
            
        } catch {
            print("Decoding error: \(error)")
        }
    }.resume()
}



func fetchCommits(for repository: Repository, username: String, completion: @escaping ([Commit]) -> Void) {
    guard let url = URL(string: "https://api.github.com/repos/\(username)/\(repository.name)/commits") else {
        print("Invalid URL")
        return
    }
    
    URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            print("Network error: \(error.localizedDescription)")
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Invalid response")
            return
        }
        
        print("Response status code: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 404 {
            print("Repository not found for \(repository.name)")
            if let data = data {
                if let errorMessage = String(data: data, encoding: .utf8) {
                    print("Error message: \(errorMessage)")
                } else {
                    print("No error message received")
                }
            } else {
                print("No data received")
            }
            return
        }
        
        guard httpResponse.statusCode == 200 else {
            print("Invalid response or status code not 200: \(httpResponse.statusCode)")
            if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
                print("Error message: \(errorMessage)")
            }
            return
        }
        
        guard let data = data else {
            print("No data received")
            return
        }
        
        do {
            let commits = try JSONDecoder().decode([Commit].self, from: data)
            DispatchQueue.main.async {
                completion(commits)
            }
        } catch {
            print("Decoding error: \(error)")
        }
    }.resume()
}

func fetchLanguages(for repository: Repository, username: String, completion: @escaping (String) -> Void) {
    guard let url = URL(string: "https://api.github.com/repos/\(username)/\(repository.name)/languages") else {
        print("Invalid URL")
        return
    }
    
    URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            print("Network error: \(error.localizedDescription)")
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Invalid response")
            return
        }
        
        print("Response status code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            print("Invalid response or status code not 200: \(httpResponse.statusCode)")
            return
        }
        
        guard let data = data else {
            print("No data received")
            return
        }
        
        do {
            let languagesDict = try JSONDecoder().decode([String: Int].self, from: data)
            let languages = languagesDict.keys.joined(separator: ", ")
            DispatchQueue.main.async {
                completion(languages)
            }
        } catch {
            print("Decoding error: \(error)")
        }
    }.resume()
}
```


