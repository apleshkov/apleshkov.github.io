//
//  ViewController.swift
//  DataViewMediator
//
//  Created by Andrew Pleshkov on 01.12.15.
//  Copyright © 2015 Andrew Pleshkov. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    private var tableView: UITableView!
    private var tableSections = [[Int]]()
    private var mediator: TableViewMediator!
    
    private static let CellIdentifier = "Cell"
    
    override func loadView() {
        super.loadView()
        
        tableView = UITableView(frame: view.bounds, style: .Plain)
        tableView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: ViewController.CellIdentifier)
        
        view.addSubview(tableView)
        
        mediator = TableViewMediator(tableView: tableView)
        mediator.setDataSource(self, delegate: self)
    }
    
    private func loadMore(more: Bool) -> Bool {
        let seconds = NSEC_PER_SEC * 2
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(seconds)), dispatch_get_main_queue()) { [weak self] () -> Void in
            var data = [Int]()
            for i in 1...5 {
                data.append(i)
            }
            self?.didLoadMore(more, data: data)
        }
        return true
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        mediator.startLoadingMore(false)
    }
    
    private func didLoadMore(more: Bool, data: [Int]) {
        if more {
            tableSections.append(data)
        } else {
            tableSections = [data]
        }
        mediator.stopLoading(updatesTable: false)
        tableView.reloadData()
    }

}

extension ViewController: TableViewMediatorDataSource {

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(ViewController.CellIdentifier, forIndexPath: indexPath)
        cell.textLabel?.text = "Item: \(tableSections[indexPath.section][indexPath.row])"
        cell.selectionStyle = .None
        return cell
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return tableSections.count
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableSections[section].count
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        // The mediator doesn't override this method, so it's necessary to disable loading section explicitly
        if section == mediator.loadingIndicatorSection {
            return nil
        }
        return "Section: \(section)"
    }

}

extension ViewController: TableViewMediatorDelegate {
    
    func tableView(tableView: UITableView, mediator: TableViewMediator, shouldLoadMore more: Bool) -> Bool {
        return loadMore(more)
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        print("Did select index path: \(indexPath)")
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 30
    }
    
}
