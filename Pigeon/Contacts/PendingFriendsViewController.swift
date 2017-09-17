//
//  PendingFriendsViewController.swift
//  Pigeon
//
//  Created by Geoffrey Ka-Hoi Law on 1/9/17.
//  Copyright © 2017 El Root. All rights reserved.
//

import UIKit
import Firebase

class PendingFriendsViewController: UITableViewController {
    
    var pendingFriends = [User]()
    
    override init(style: UITableViewStyle) {
        super.init(style: style)
        
        fetchPendingFriends()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNavigation()
        setupViews()
        setupTableView()
    }
    
    func reloadData() {
        pendingFriends.removeAll()
        tableView.reloadData()
        
        fetchPendingFriends()
    }
    
    fileprivate func setupNavigation() {
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.tintColor = .black
        navigationItem.title = "Pending Friends"
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
    }
    
    fileprivate func setupViews() {
        view.backgroundColor = .groupTableViewBackground
    }
    
    fileprivate func setupTableView() {
        tableView.tableFooterView = UIView()
        tableView.register(PendingFriendsTableViewCell.self, forCellReuseIdentifier: "PendingFriendsCell")
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pendingFriends.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PendingFriendsCell", for: indexPath)
        
        if let cell = cell as? PendingFriendsTableViewCell {
            cell.user = pendingFriends[indexPath.row]
            if let isApproved = cell.user?.isApproved, isApproved {
                cell.approveButton.isEnabled = false
                cell.approveButton.setTitle("Approved", for: .disabled)
                cell.approveButton.backgroundColor = .lightGray
            } else {
                cell.approveButton.isEnabled = true
            }
            cell.approveButton.tag = indexPath.row
            cell.approveButton.addTarget(self, action: #selector(handleApprove), for: .touchUpInside)
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 64
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let vc = UserProfileViewController()
        vc.user = pendingFriends[indexPath.row]
        navigationController?.pushViewController(vc, animated: true)
    }
    
    fileprivate func fetchPendingFriends() {
        guard let currentUser = Auth.auth().currentUser else { return }
        Database.database().reference().child("pending-friends").observeSingleEvent(of: .value) { (dataSnapshot) in
            guard let snapshots = dataSnapshot.children.allObjects as? [DataSnapshot] else { return }
            var senders = [String]()
            for snapshot in snapshots {
                if snapshot.childSnapshot(forPath: "to").value as? String == currentUser.uid {
                    guard let sender = snapshot.childSnapshot(forPath: "from").value as? String else { return }
                    senders.append(sender)
                }
            }
            
            Database.database().reference().child("users").observeSingleEvent(of: .value, with: { (dataSnapshot) in
                guard let snapshots = dataSnapshot.children.allObjects as? [DataSnapshot] else { return }
                for sender in senders {
                    for snapshot in snapshots {
                        if sender == snapshot.key {
                            if let dictionary = snapshot.value as? [String: AnyObject] {
                                let pendingFriend = User(uid: snapshot.key, dictionary)
                                self.pendingFriends.append(pendingFriend)
                            }
                        }
                    }
                }
                
                Database.database().reference().child("friends").observeSingleEvent(of: .value, with: { (friendshipDataSnapshot) in
                    guard let friendships = friendshipDataSnapshot.children.allObjects as? [DataSnapshot] else { return }
                    for friendship in friendships {
                        if friendship.childSnapshot(forPath: "to").value as? String != currentUser.uid {
                            continue
                        }
                        
                        for pendingFriend in self.pendingFriends {
                            if friendship.childSnapshot(forPath: "from").value as? String == pendingFriend.uid {
                                pendingFriend.isApproved = true
                            } else {
                                UserFriendsData.shared.pendingFriends.append(pendingFriend)
                            }
                        }
                    }
                    
                    DispatchQueue.main.async(execute: {
                        self.tableView.reloadData()
                    })
                })
            })
        }
    }
    
    @objc fileprivate func handleApprove(sender: UIButton) {
        guard let currentUser = Auth.auth().currentUser else { return }
        let timestamp: NSNumber = NSNumber(value: Int(NSDate().timeIntervalSince1970))
        let values = ["from": pendingFriends[sender.tag].uid!, "to": currentUser.uid, "timestamp": timestamp] as [String : Any]
        Database.database().reference().child("friends").childByAutoId().updateChildValues(values) { (error, ref) in
            if let error = error {
                let alert = UIAlertController(title: "Error", message: String(describing: error), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
                return
            }
            
            self.sendApproveNotification(sender: currentUser.uid, receiver: self.pendingFriends[sender.tag].uid!)
            
            let values = [ref.key: timestamp]
            Database.database().reference().child("user-friends").child(currentUser.uid).updateChildValues(values, withCompletionBlock: { (err, _) in
                if let err = err {
                    let alert = UIAlertController(title: "Error", message: String(describing: err), preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                    return
                }
            })
            Database.database().reference().child("user-friends").child(self.pendingFriends[sender.tag].uid!).updateChildValues(values, withCompletionBlock: { (err, _) in
                if let err = err {
                    let alert = UIAlertController(title: "Error", message: String(describing: err), preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                    return
                }
            })
            
            let timestamp: NSNumber = NSNumber(value: Int(NSDate().timeIntervalSince1970))
            Database.database().reference().child("conversations").childByAutoId().updateChildValues(["timestamp": timestamp], withCompletionBlock: { (error, ref) in
                if let error = error {
                    let alert = UIAlertController(title: "Error", message: String(describing: error), preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                    return
                }
                let toUID = self.pendingFriends[sender.tag].uid!
                let fromUID = currentUser.uid
                let fromValues = [toUID: ref.key]
                let toValues = [fromUID: ref.key]
                Database.database().reference().child("user-conversations").child(fromUID).updateChildValues(fromValues, withCompletionBlock: { (error, ref) in
                    if let error = error {
                        let alert = UIAlertController(title: "Error", message: String(describing: error), preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                        return
                    }
                })
                Database.database().reference().child("user-conversations").child(toUID).updateChildValues(toValues, withCompletionBlock: { (error, ref) in
                    if let error = error {
                        let alert = UIAlertController(title: "Error", message: String(describing: error), preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                        return
                    }
                })
            })
            
            DispatchQueue.main.async(execute: {
                sender.isEnabled = false
                sender.setTitle("Approved", for: .disabled)
                sender.backgroundColor = .lightGray
            })
        }
    }
    
    fileprivate func sendApproveNotification(sender: String, receiver: String) {
        Database.database().reference().child("users").child(sender).child("username").observeSingleEvent(of: .value) { (dataSnapshot) in
            guard let username = dataSnapshot.value as? String else { return }
            
            guard let url = URL(string: "https://onesignal.com/api/v1/notifications") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Basic MGRkNDU1YjUtYzNkMy00ODYwLWIxNDctMTQ4MjAyOWI4MjI2", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let jsonObject: [String: Any] = [
                "app_id": "eb1565de-1624-4ab0-8392-ff39800489d2",
                "filters": [
                    [
                        "field": "tag",
                        "key": "uid",
                        "relation": "=",
                        "value": receiver
                    ]
                ],
                "contents": [
                    "en": "[\(String(describing: username))]: Your friend request has been approved."
                ]
            ]
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
                request.httpBody = jsonData
            } catch {
                print("Error JSON")
                return
            }
            
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    print(error)
                    return
                }
                
                if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                    print("statusCode should be 200, but is \(httpStatus.statusCode)")
                    print("response = \(String(describing: response))")
                }
                
                let responseString = String(data: data!, encoding: .utf8)
                print("responseString = \(String(describing: responseString))")
            }
            task.resume()
        }
    }

}
