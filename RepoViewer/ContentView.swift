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
