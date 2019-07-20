//
//  SessionsTableViewController.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 24/07/16.
//  Copyright © 2016 Timothy Sealy. All rights reserved.
//

import UIKit

class SessionsTableViewController: UITableViewController {
    
    var archiveMapViewVC : ArchiveMapViewController?
    var defaultNavBarTint : UIColor?
    var files : [String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Use the edit button item provided by the table view controller.
        self.navigationItem.rightBarButtonItem = self.editButtonItem
        self.navigationItem.rightBarButtonItem?.tintColor = UIColor.orange
        
        // Get a list of sessions.
        files = TTNMapperLocalStorage.sharedInstance.listSessions()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        // Set the ttnmapperSession if we are transitioning to the mapviewer
        self.archiveMapViewVC = segue.destination as? ArchiveMapViewController
    }

    @IBAction func onLiveMapTap(_ sender: UIBarButtonItem) {
        // Clear archive map vc.
        self.archiveMapViewVC = nil
        let _ = self.navigationController?.popToRootViewController(animated: true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return files.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "SessionCell", for: indexPath)
        let filename = files[indexPath.row]
        cell.textLabel?.text = filename
        
        return cell
    }
    
    // Override to handle the selection of a session.
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        // Open file.
        let filename = files[indexPath.row]
        let archivedSession = TTNMapperLocalStorage.sharedInstance.loadSession(filename)
        
        if let archiveMapViewVC = archiveMapViewVC {
            archiveMapViewVC.ttnmapperSession = archivedSession
        }
    }

    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == .delete {
            // Delete the row from the data source
            let filename = files[indexPath.row]
            TTNMapperLocalStorage.sharedInstance.deleteSession(filename)
        
            // Remove item from innerlist.
            files.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }

}
