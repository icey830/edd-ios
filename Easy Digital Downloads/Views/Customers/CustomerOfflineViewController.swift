//
//  CustomerOfflineViewController.swift
//  Easy Digital Downloads
//
//  Created by Sunny Ratilal on 26/09/2016.
//  Copyright © 2016 Easy Digital Downloads. All rights reserved.
//

import UIKit
import CoreData
import SwiftyJSON
import Haneke

private let sharedDateFormatter: NSDateFormatter = {
    let formatter = NSDateFormatter()
    formatter.calendar = NSCalendar(calendarIdentifier: NSCalendarIdentifierISO8601)
    formatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
    formatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter
}()

class CustomerOfflineViewController: SiteTableViewController {

    var managedObjectContext: NSManagedObjectContext!
    
    typealias JSON = SwiftyJSON.JSON
    
    private enum CellType {
        case Profile
        case Stats
        case SalesHeading
        case Sales
        case SubscriptionsHeading
        case Subscriptions
    }
    
    private var cells = [CellType]()
    
    var site: Site?
    var customer: Customer?
    var recentSales: [JSON]?
    var recentSubscriptions: [JSON]?
    var email: String?
    let sharedCache = Shared.dataCache
    
    var loadingView = UIView()
    
    init(email: String) {
        super.init(style: .Plain)
        
        self.site = Site.activeSite()
        self.email = email
        self.managedObjectContext = AppDelegate.sharedInstance.managedObjectContext
        
        title = NSLocalizedString("Fetching Customer...", comment: "")
        
        let titleLabel = ViewControllerTitleLabel()
        titleLabel.setTitle(email)
        self.navigationItem.titleView = titleLabel
        
        view.backgroundColor = .EDDGreyColor()
        
        loadingView = {
            var frame: CGRect = self.view.frame;
            frame.origin.x = 0;
            frame.origin.y = 0;
            
            let view = UIView(frame: frame)
            view.autoresizingMask = [.FlexibleHeight, .FlexibleWidth]
            view.backgroundColor = .EDDGreyColor()
            
            return view
        }()
        
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
        activityIndicator.autoresizingMask = [.FlexibleLeftMargin, .FlexibleRightMargin, .FlexibleTopMargin, .FlexibleBottomMargin]
        activityIndicator.center = view.center
        loadingView.addSubview(activityIndicator)
        
        activityIndicator.startAnimating()
        
        view.addSubview(loadingView)
        
        networkOperations()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 120.0
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.separatorStyle = .None
        
        tableView.registerClass(CustomerProfileTableViewCell.self, forCellReuseIdentifier: "CustomerProfileTableViewCell")
        tableView.registerClass(CustomerStatsTableViewCell.self, forCellReuseIdentifier: "CustomerStatsTableViewCell")
        tableView.registerClass(CustomerDetailHeadingTableViewCell.self, forCellReuseIdentifier: "CustomerHeadingTableViewCell")
        tableView.registerClass(CustomerRecentSaleTableViewCell.self, forCellReuseIdentifier: "CustomerRecentSaleTableViewCell")
        tableView.registerClass(CustomerDetailSubscriptionTableViewCell.self, forCellReuseIdentifier: "CustomerSubscriptionTableViewCell")
        
        sharedCache.fetch(key: Site.activeSite().uid! + "-Customer-" + email).onSuccess({ result in
            let json = JSON.convertFromData(result)! as JSON
            
            if let items = json["customers"].array {
                let item = items[0]
                
                self.customer = Customer.objectForData(AppDelegate.sharedInstance.managedObjectContext, displayName: item["info"]["display_name"].stringValue, email: item["info"]["email"].stringValue, firstName: item["info"]["first_name"].stringValue, lastName: item["info"]["last_name"].stringValue, totalDownloads: item["stats"]["total_downloads"].int64Value, totalPurchases: item["stats"]["total_purchases"].int64Value, totalSpent: item["stats"]["total_spent"].doubleValue, uid: item["info"]["customer_id"].int64Value, username: item["username"].stringValue, dateCreated: sharedDateFormatter.dateFromString(item["info"]["date_created"].stringValue)!)
                
                dispatch_async(dispatch_get_main_queue(), {
                    let titleLabel = ViewControllerTitleLabel()
                    titleLabel.setTitle(item["info"]["display_name"].stringValue)
                    self.navigationItem.titleView = titleLabel
                    
                    self.tableView.reloadData()
                    self.loadingView.removeFromSuperview()
                })
            }
        })
        
        cells = [.Profile, .Stats]
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    private func networkOperations() {
        EDDAPIWrapper.sharedInstance.requestCustomers(["customer" : email!], success: { (json) in
            // Cache the returned customer
            self.sharedCache.set(value: json.asData(), key: Site.activeSite().uid! + "-Customer-" + self.email!)

            if let items = json["customers"].array {
                let item = items[0]
                
                self.customer = Customer.objectForData(AppDelegate.sharedInstance.managedObjectContext, displayName: item["info"]["display_name"].stringValue, email: item["info"]["email"].stringValue, firstName: item["info"]["first_name"].stringValue, lastName: item["info"]["last_name"].stringValue, totalDownloads: item["stats"]["total_downloads"].int64Value, totalPurchases: item["stats"]["total_purchases"].int64Value, totalSpent: item["stats"]["total_spent"].doubleValue, uid: item["info"]["customer_id"].int64Value, username: item["username"].stringValue, dateCreated: sharedDateFormatter.dateFromString(item["info"]["date_created"].stringValue)!)
                
                dispatch_async(dispatch_get_main_queue(), {
                    self.tableView.reloadData()
                    self.title = item["info"]["display_name"].stringValue
                    
                    let titleLabel = ViewControllerTitleLabel()
                    titleLabel.setTitle(item["info"]["display_name"].stringValue)
                    self.navigationItem.titleView = titleLabel
                    self.loadingView.removeFromSuperview()
                })
            }
            }) { (error) in
                print(error)
        }
        
        EDDAPIWrapper.sharedInstance.requestSales(["email" : email!], success: { (json) in
            if let items = json["sales"].array {
                self.cells.append(.SalesHeading)
                self.recentSales = items
                for _ in 1...items.count {
                    self.cells.append(.Sales)
                }
                dispatch_async(dispatch_get_main_queue(), {
                    self.tableView.reloadData()
                })
            }
        }) { (error) in
            print(error.localizedDescription)
        }
        
        if (Site.activeSite().hasRecurring != nil) {
            EDDAPIWrapper.sharedInstance.requestSubscriptions(["customer" : email!], success: { (json) in
                if let items = json["subscriptions"].array {
                    self.cells.append(.SubscriptionsHeading)
                    self.recentSubscriptions = items
                    for _ in 1...items.count {
                        self.cells.append(.Subscriptions)
                    }
                    dispatch_async(dispatch_get_main_queue(), {
                        self.tableView.reloadData()
                    })
                }
            }) { (error) in
                print(error.localizedDescription)
            }
        }
    }
    
    // MARK: Table View Data Source
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cells.count
    }
    
    // MARK: Table View Delegate
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if cells[indexPath.row] == CellType.Sales {
            var offset = 0
            if cells[2] == CellType.SubscriptionsHeading {
                offset = indexPath.row - (recentSubscriptions?.count)! - 4
                
            } else {
                offset = indexPath.row - 3
            }
            
            let item = recentSales![offset]
            
            let sale = Sales(ID: item["ID"].int64Value, transactionId: item["transaction_id"].stringValue, key: item["key"].stringValue, subtotal: item["subtotal"].doubleValue, tax: item["tax"].double, fees: item["fees"].array, total: item["total"].doubleValue, gateway: item["gateway"].stringValue, email: item["email"].stringValue, date: sharedDateFormatter.dateFromString(item["date"].stringValue), discounts: item["discounts"].dictionary, products: item["products"].arrayValue, licenses: item["licenses"].array)
            
            navigationController?.pushViewController(SalesDetailViewController(sale: sale), animated: true)
        }
        
        if cells[indexPath.row] == CellType.Subscriptions {
            var offset = 0
            if cells[2] == CellType.SalesHeading {
                offset = indexPath.row - (recentSales?.count)! - 4
                
            } else {
                offset = indexPath.row - 3
            }
            
            let item = recentSubscriptions![offset]
            
            let subscription = Subscriptions(ID: item["info"]["id"].int64Value, customerId: item["info"]["customer_id"].int64Value, period: item["info"]["period"].stringValue, initialAmount: item["info"]["initial_amount"].doubleValue, recurringAmount: item["info"]["recurring_amount"].doubleValue, billTimes: item["info"]["bill_times"].int64Value, transactionId: item["info"]["transaction_id"].stringValue, parentPaymentId: item["info"]["parent_payment_id"].int64Value, productId: item["info"]["product_id"].int64Value, created: sharedDateFormatter.dateFromString(item["info"]["created"].stringValue), expiration: sharedDateFormatter.dateFromString(item["info"]["expiration"].stringValue), status: item["info"]["status"].stringValue, profileId: item["info"]["profile_id"].stringValue, gateway: item["info"]["gateway"].stringValue, customer: item["info"]["customer"].dictionaryValue, renewalPayments: item["payments"].array)
            
            navigationController?.pushViewController(SubscriptionsDetailViewController(subscription: subscription), animated: true)
        }
        
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell: UITableViewCell!
        
        switch(cells[indexPath.row]) {
            case .Profile:
                cell = tableView.dequeueReusableCellWithIdentifier("CustomerProfileTableViewCell", forIndexPath: indexPath) as! CustomerProfileTableViewCell
                if let customerObj = customer {
                    (cell as! CustomerProfileTableViewCell).configure(customerObj)
                }
            case .Stats:
                cell = tableView.dequeueReusableCellWithIdentifier("CustomerStatsTableViewCell", forIndexPath: indexPath) as! CustomerStatsTableViewCell
                if let customerObj = customer {
                    (cell as! CustomerStatsTableViewCell).configure(customerObj)
                }
            case .SalesHeading:
                cell = tableView.dequeueReusableCellWithIdentifier("CustomerHeadingTableViewCell", forIndexPath: indexPath) as! CustomerDetailHeadingTableViewCell
                (cell as! CustomerDetailHeadingTableViewCell).configure("Recent Sales")
            case .Sales:
                cell = tableView.dequeueReusableCellWithIdentifier("CustomerRecentSaleTableViewCell", forIndexPath: indexPath) as! CustomerRecentSaleTableViewCell
                var offset = 0
                if cells[2] == CellType.SubscriptionsHeading {
                    offset = indexPath.row - (recentSubscriptions?.count)! - 4
                    
                } else {
                    offset = indexPath.row - 3
                }
                (cell as! CustomerRecentSaleTableViewCell).configure(recentSales![offset])
            case .SubscriptionsHeading:
                cell = tableView.dequeueReusableCellWithIdentifier("CustomerHeadingTableViewCell", forIndexPath: indexPath) as! CustomerDetailHeadingTableViewCell
                (cell as! CustomerDetailHeadingTableViewCell).configure("Recent Subscriptions")
            case .Subscriptions:
                cell = tableView.dequeueReusableCellWithIdentifier("CustomerSubscriptionTableViewCell", forIndexPath: indexPath) as! CustomerDetailSubscriptionTableViewCell
                var offset = 0
                if cells[2] == CellType.SalesHeading {
                    offset = indexPath.row - (recentSales?.count)! - 4
                    
                } else {
                    offset = indexPath.row - 3
                }
                (cell as! CustomerDetailSubscriptionTableViewCell).configure(recentSubscriptions![offset])
        }
        
        return cell!
    }


}