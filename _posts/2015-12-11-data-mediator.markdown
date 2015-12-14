---
layout: post
title:  "Data Mediator"
tags: swift UITableView uicollectionview
---
# Data View Mediator

This article describes an approach to separate some routine code from view controllers.

Working with `UITableView` or `UICollectionView`, we often have to write some routine code which repeats from controller to controller. It could be loading indicators, specific footers or supplementary views. The very common solution is to create a _base_ view controller, put such logic there and subclass it.

![d1](/assets/data-mediator/d1.png)

But what if we can avoid such inheritance? This article describes a possible solution. Just an approach, not a framework, because it's very project-specific.

## Mediator to the rescue!

The main idea is to create a layer between view controller and table/collection view dataSource & delegate.

![d2](/assets/data-mediator/d2.png)

## Example

Let's take a view controllers with `UITableView`s. For example we'll implement a loading indicator for infinite scroll and add `UIRefreshControl` for data reloading.

Apart from implementing `UITableViewDataSource` & `UITableViewDelegate` methods (see diagram) our controllers should be able to:

* refresh loaded data if one uses `UIRefreshControl`
* load next page if one reaches a table's end while scrolling

So we put refresh/scroll handling to the mediator and it's absolutely doesn't matter what data we load, how we load, how it should be rendered and so on.

## Implementation

We'll do a very easy implementation to show the approach.

The main part is **proxying**:

* the mediator exposes its own protocols `TableViewMediatorDataSource` & `TableViewMediatorDelegate`
* the mediator sets itself as a table `dataSource` & `delegate`
* the mediator proxies every unhandled call from table protocols to its own protocols

![d3](/assets/data-mediator/d3.png)

{% highlight swift %}
public class TableViewMediator: NSObject {

    private var tableView: UITableView!

    private(set) weak var dataSource: TableViewMediatorDataSource?
    private(set) weak var delegate: TableViewMediatorDelegate?

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

        refreshControl = UIRefreshControl()
        refreshControl!.addTarget(self, action: "refreshControlDidChangeValue:", forControlEvents: .ValueChanged)
        tableView.addSubview(refreshControl!)
    }

}
{% endhighlight %}

### The mediator protocols

{% highlight swift %}
public protocol TableViewMediatorDataSource: UITableViewDataSource {
}


@objc public protocol TableViewMediatorDelegate: UITableViewDelegate {

    // more: true - load next page, false - reload data
    optional func tableView(tableView: UITableView, mediator: TableViewMediator, shouldLoadMore more: Bool) -> Bool

}
{% endhighlight %}

Both protocols are subclassed from corresponding `UITableView` protocols.

### Time to proxy

{% highlight swift %}
public class TableViewMediator: NSObject {

    ...

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
{% endhighlight %}

### Conforming the `UITableView` protocols

{% highlight swift %}
extension TableViewMediator: UITableViewDataSource {

    public func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        var count = 1 // by default (see apple doc)
        if let num = dataSource?.numberOfSectionsInTableView?(tableView) {
            count = num
        }
        loadingIndicatorSection = count++ // add additional section for the loading indicator
        return count
    }

}
{% endhighlight %}

Notice we add an additional property:

{% highlight swift %}
private(set) var loadingIndicatorSection: Int?
{% endhighlight %}

The loading indicator cell:

{% highlight swift %}
private static let LoadingCellIdentifier = "MediatorLoadingCell"

...

tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: TableViewMediator.LoadingCellIdentifier)
{% endhighlight %}

Completing the data source:

{% highlight swift %}
extension TableViewMediator: UITableViewDataSource {

    ...

    public func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == loadingIndicatorSection {
            return 1 // just one cell
        }
        // external numbers
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
        // external cells
        return dataSource!.tableView(tableView, cellForRowAtIndexPath: indexPath)
    }

}
{% endhighlight %}

The loading indicator height:

{% highlight swift %}
extension TableViewMediator: UITableViewDelegate {

    public func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.section == loadingIndicatorSection {
            if shouldShowLoadingIndicator { // visible
                return 30
            }
            return 0 // hidden
        }
        // external heights
        if let rowHeight = delegate?.tableView?(tableView, heightForRowAtIndexPath: indexPath) {
            return rowHeight
        }
        // default height
        return tableView.rowHeight
    }

}
{% endhighlight %}

`shouldShowLoadingIndicator`:

{% highlight swift %}
private(set) var loadingState = false
private var shouldShowLoadingIndicator: Bool {
    // don't show the loading indicator if the refresh control is in use
    return (loadingState || refreshControl?.refreshing == true)
}
{% endhighlight %}

Methods to set `loadingState` and `UIRefreshControl` handling:

{% highlight swift %}
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
        loadingState = tryLoadMore(false) // more = false
        if (!loadingState) {
            refreshControl.endRefreshing()
        }
    }

}
{% endhighlight %}

Start & stop methods are public, so a controller can use them like:

1. start loading - show loading indicator via the mediator
2. handle loading completion - stop loading - hide loading indicator via the mediator

Infinite scroll:

{% highlight swift %}
extension TableViewMediator: UITableViewDelegate {

    ...

    public func scrollViewDidScroll(scrollView: UIScrollView) {
        // don't forget an external delegate
        delegate?.scrollViewDidScroll?(scrollView)
        if shouldShowLoadingIndicator {
            return
        }
        if scrollView.contentOffset.y > 0 {
            let value = (scrollView.contentSize.height - scrollView.contentOffset.y - scrollView.bounds.height - max(scrollView.contentInset.top, 0) - max(scrollView.contentInset.bottom, 0))
            // the end is here
            if value <= 0 {
                startLoadingMore(true) // more = true
            }
        }
    }

}
{% endhighlight %}

### Controller

We got a simple mediator now! Let's write a controller:

{% highlight swift %}
class ViewController: UIViewController {

    private var tableView: UITableView!
    private var mediator: TableViewMediator!

    override func loadView() {
        super.loadView()

        tableView = ...

        view.addSubview(tableView)

        mediator = TableViewMediator(tableView: tableView)
        mediator.setDataSource(self, delegate: self)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        mediator.startLoadingMore(false) // shows indicator & calls delegate's tableView(_:mediator:shouldLoadMore:)
    }

}

extension ViewController: TableViewMediatorDataSource {

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        // as usual
        ...
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // as usual
        ...
    }

}

extension ViewController: TableViewMediatorDelegate {

    func tableView(tableView: UITableView, mediator: TableViewMediator, shouldLoadMore more: Bool) -> Bool {
        // load data and return true, return false if loading is impossible
        ...
    }

}
{% endhighlight %}

See full example {% include example.html path='mediator/DataViewMediator' name='here' %}
