//
//  FeedViewController.swift
//  lab-insta-parse
//
//  Created by Charlie Hieger on 11/1/22.
//

import UIKit
import ParseSwift

class FeedViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    private let refreshControl = UIRefreshControl()

    private var posts = [Post]() {
        didSet {
            // Reload table view data any time the posts variable gets updated.
            tableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsSelection = false

        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(onPullToRefresh), for: .valueChanged)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        queryPosts()
    }

    private func queryPosts(completion: (() -> Void)? = nil) {
        // Get the date for yesterday. Adding (-1) day is equivalent to subtracting a day.
        guard let yesterdayDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return }
        
        let query = Post.query()
            .include("user")
            .order([.descending("createdAt")])
            .where("createdAt" >= yesterdayDate) // Only include results created yesterday onwards
            .limit(10) // Limit max number of returned posts to 10

        // Find and return posts that meet query criteria (async)
        query.find { [weak self] result in
            // Always switch back to the main thread for UI updates and callbacks
            DispatchQueue.main.async {
                switch result {
                case .success(let posts):
                    // Update the local posts property with fetched posts
                    self?.posts = posts
                case .failure(let error):
                    self?.showAlert(description: error.localizedDescription)
                }

                // Call the completion handler on the main thread to stop pull-to-refresh
                completion?()
            }
        }
    }

    @IBAction func onLogOutTapped(_ sender: Any) {
        showConfirmLogoutAlert()
    }

    @objc private func onPullToRefresh() {
        refreshControl.beginRefreshing()
        queryPosts { [weak self] in
            self?.refreshControl.endRefreshing()
        }
    }

    private func showConfirmLogoutAlert() {
        let alertController = UIAlertController(
            title: "Log out of \(User.current?.username ?? "current account")?",
            message: nil,
            preferredStyle: .alert
        )
        let logOutAction = UIAlertAction(title: "Log out", style: .destructive) { _ in
            // Log out current user in Parse
            User.logout { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        // Post notification to reset root view controller to login
                        NotificationCenter.default.post(name: Notification.Name("logout"), object: nil)
                    case .failure(let error):
                        print("❌ Logout error: \(error.localizedDescription)")
                    }
                }
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alertController.addAction(logOutAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension FeedViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return posts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "PostCell", for: indexPath) as? PostCell else {
            return UITableViewCell()
        }
        cell.configure(with: posts[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate
extension FeedViewController: UITableViewDelegate { }
