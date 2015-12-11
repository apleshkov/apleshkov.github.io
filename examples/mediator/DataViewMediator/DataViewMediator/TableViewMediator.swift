//
//  TableViewMediator.swift
//  DataViewMediator
//
//  Created by Andrew Pleshkov on 01.12.15.
//  Copyright © 2015 Andrew Pleshkov. All rights reserved.
//

import Foundation
import UIKit

public class TableViewMediator: NSObject {

    private var tableView: UITableView!
    
    private(set) weak var dataSource: TableViewMediatorDataSource?
    private(set) weak var delegate: TableViewMediatorDelegate?
    
    private(set) var loadingState = false
    private(set) var loadingIndicatorSection: Int?
    private var shouldShowLoadingIndicator: Bool {
        return (loadingState || refreshControl?.refreshing == true)
    }
    private static let LoadingCellIdentifier = "MediatorLoadingCell"
    
    private var refreshControl: UIRefreshControl?
    
    public init(tableView: UITableView) {
        super.init()
        self.tableView = tableView
    }
    
    public func setDataSource(dataSource: TableViewMediatorDataSource, delegate: TableViewMediatorDelegate?) {
        self.dataSource = dataSource
        self.delegate = delegate
        
        tableView.dataSource = self
        tableView.delegate = self
        
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: TableViewMediator.LoadingCellIdentifier)
        
        refreshControl = UIRefreshControl()
        refreshControl!.addTarget(self, action: "refreshControlDidChangeValue:", forControlEvents: .ValueChanged)
        tableView.addSubview(refreshControl!)
    }
    
    // MARK: Proxy
    
    public override func respondsToSelector(aSelector: Selector) -> Bool {
        return (super.respondsToSelector(aSelector)
            || (dataSource?.respondsToSelector(aSelector) ?? false)
            || (delegate?.respondsToSelector(aSelector) ?? false))
    }
    
    public override func forwardingTargetForSelector(aSelector: Selector) -> AnyObject? {
        if dataSource?.respondsToSelector(aSelector) == true {
            return dataSource
        }
        if delegate?.respondsToSelector(aSelector) == true {
            return delegate
        }
        return super.forwardingTargetForSelector(aSelector)
    }
    
}

extension TableViewMediator {
    
    private func tryLoadMore(more: Bool) -> Bool {
        if let result = self.delegate?.tableView?(tableView, mediator: self, shouldLoadMore: more) {
            return result
        }
        return false
    }
    
    public func startLoadingMore(more: Bool, updatesTable: Bool = true) {
        if !loadingState && refreshControl?.refreshing == false {
            loadingState = tryLoadMore(more)
            if updatesTable {
                tableView.reloadData()
            }
        }
    }
    
    public func stopLoading(updatesTable updatesTable: Bool = true) {
        refreshControl?.endRefreshing()
        if loadingState {
            loadingState = false
            if updatesTable {
                tableView.reloadData()
            }
        }
    }
    
    @objc private func refreshControlDidChangeValue(refreshControl: UIRefreshControl) {
        if loadingState || !refreshControl.refreshing {
            return
        }
        loadingState = tryLoadMore(false)
        if (!loadingState) {
            refreshControl.endRefreshing()
        }
    }
    
}

extension TableViewMediator: UITableViewDataSource {
    
    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        var count = 1
        if let num = dataSource?.numberOfSectionsInTableView?(tableView) {
            count = num
        }
        loadingIndicatorSection = count++
        return count
    }
    
    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == loadingIndicatorSection {
            return 1
        }
        return dataSource!.tableView(tableView, numberOfRowsInSection: section)
    }
    
    public func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.section == loadingIndicatorSection {
            let cell = tableView.dequeueReusableCellWithIdentifier(TableViewMediator.LoadingCellIdentifier, forIndexPath: indexPath)
            if let textLabel = cell.textLabel {
                textLabel.textColor = UIColor.redColor()
                textLabel.text = "Loading..."
                textLabel.textAlignment = .Center
            }
            cell.selectionStyle = .None
            return cell
        }
        return dataSource!.tableView(tableView, cellForRowAtIndexPath: indexPath)
    }

}

extension TableViewMediator: UITableViewDelegate {
    
    public func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.section == loadingIndicatorSection {
            if shouldShowLoadingIndicator {
                return 30
            }
            return 0
        }
        if let rowHeight = delegate?.tableView?(tableView, heightForRowAtIndexPath: indexPath) {
            return rowHeight
        }
        return tableView.rowHeight
    }
    
    public func scrollViewDidScroll(scrollView: UIScrollView) {
        delegate?.scrollViewDidScroll?(scrollView)
        if shouldShowLoadingIndicator {
            return
        }
        if scrollView.contentOffset.y > 0 {
            let value = (scrollView.contentSize.height - scrollView.contentOffset.y - scrollView.bounds.height - max(scrollView.contentInset.top, 0) - max(scrollView.contentInset.bottom, 0))
            if value <= 0 {
                startLoadingMore(true)
            }
        }
    }
    
}


// MARK: - Data Source


public protocol TableViewMediatorDataSource: UITableViewDataSource {
}


// MARK: - Delegate


@objc public protocol TableViewMediatorDelegate: UITableViewDelegate {

    optional func tableView(tableView: UITableView, mediator: TableViewMediator, shouldLoadMore more: Bool) -> Bool

}
