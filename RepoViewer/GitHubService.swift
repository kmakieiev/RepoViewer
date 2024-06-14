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

