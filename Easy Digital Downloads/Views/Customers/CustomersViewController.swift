//
//  CustomersViewController.swift
//  Easy Digital Downloads
//
//  Created by Sunny Ratilal on 28/05/2016.
//  Copyright © 2016 Easy Digital Downloads. All rights reserved.
//

import UIKit
import CoreData
import SwiftyJSON

class CustomersViewController: SiteTableViewController, ManagedObjectContextSettable {

    var managedObjectContext: NSManagedObjectContext!
    
    var site: Site?
    var customers: [JSON]?
    
    var hasMoreCustomers: Bool = true {
        didSet {
            if (!hasMoreCustomers) {
                activityIndicatorView.stopAnimating()
            } else {
                activityIndicatorView.startAnimating()
            }
        }
    }
    
    var lastDownloadedPage = NSUserDefaults.standardUserDefaults().integerForKey("\(Site.activeSite().uid)-CustomersPage") ?? 0

    override func viewDidLoad() {
        super.viewDidLoad()
        setupInfiniteScrollView()
        setupTableView()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    init(site: Site) {
        super.init(style: .Plain)
        
        self.site = site
        self.managedObjectContext = AppDelegate.sharedInstance.managedObjectContext
        
        title = NSLocalizedString("Customers", comment: "Customers title")
    }


    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        customers = [JSON]()
        
        EDDAPIWrapper.sharedInstance.requestCustomers([:], success: { (json) in
            if let items = json["customers"].array {
                self.customers = items
                self.updateLastDownloadedPage()
                self.requestNextPage()
            }
            }) { (error) in
                NSLog(error.localizedDescription)
        }
    }
    
    // MARK: Private
    
    private func requestNextPage() {
        EDDAPIWrapper.sharedInstance.requestCustomers([ "page": lastDownloadedPage ], success: { (json) in
            if let items = json["customers"].array {
                if items.count == 50 {
                    self.hasMoreCustomers = true
                } else {
                    self.hasMoreCustomers = false
                }
                for item in items {
                    self.customers?.append(item)
                }
                self.updateLastDownloadedPage()
            } else {
                self.hasMoreCustomers = false
            }
            self.persistCustomers()
        }) { (error) in
            fatalError()
        }
    }
    
    private func updateLastDownloadedPage() {
        self.lastDownloadedPage = self.lastDownloadedPage + 1;
        NSUserDefaults.standardUserDefaults().setInteger(lastDownloadedPage, forKey: "\(Site.activeSite().uid)-CustomersPage")
    }
    
    private func persistCustomers() {
        guard let customers_ = customers else {
            return
        }
        
        for item in customers_ {
            
        }
    }
    
    private typealias Data = FetchedResultsDataProvider<CustomersViewController>
    private var dataSource: TableViewDataSource<CustomersViewController, Data, CustomersTableViewCell>!
    
    private func setupTableView() {
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 44
        tableView.registerClass(CustomersTableViewCell.self, forCellReuseIdentifier: "CustomerCell")
        setupDataSource()
    }
    
    private func setupDataSource() {
        let request = Customer.defaultFetchRequest()
        let frc = NSFetchedResultsController(fetchRequest: request, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        let dataProvider = FetchedResultsDataProvider(fetchedResultsController: frc, delegate: self)
        dataSource = TableViewDataSource(tableView: tableView, dataProvider: dataProvider, delegate: self)
    }
    
}

extension CustomersViewController: DataProviderDelegate {
    
    func dataProviderDidUpdate(updates: [DataProviderUpdate<Customer>]?) {
        dataSource.processUpdates(updates)
    }
    
}

extension CustomersViewController: DataSourceDelegate {
    
    func cellIdentifierForObject(object: Customer) -> String {
        return "CustomerCell"
    }
    
}

extension CustomersViewController : InfiniteScrollingTableView {
    
    func setupInfiniteScrollView() {
        let bounds = UIScreen.mainScreen().bounds
        let width = bounds.size.width
        
        let footerView = UIView(frame: CGRectMake(0, 0, width, 44))
        footerView.backgroundColor = .clearColor()
        
        activityIndicatorView.startAnimating()
        
        footerView.addSubview(activityIndicatorView)
        
        tableView.tableFooterView = footerView
    }
    
}