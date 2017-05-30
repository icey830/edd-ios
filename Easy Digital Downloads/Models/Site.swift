//
//  Site.swift
//  Easy Digital Downloads
//
//  Created by Sunny Ratilal on 29/05/2016.
//  Copyright © 2016 Easy Digital Downloads. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import SSKeychain

let CreatedTimestampKey = "createdAt"

enum SiteType: Int16 {
    case Standard = 0
    case Store = 1
    case Commission = 2
    case StandardStore = 3
    case StandardCommission = 4
}

private let sharedNumberFormatter: NSNumberFormatter = {
    let formatter = NSNumberFormatter()
    formatter.numberStyle = .CurrencyStyle
    formatter.currencyCode = Site.activeSite().currency!
    return formatter
}()

private let sharedDefaults: NSUserDefaults = {
   return NSUserDefaults(suiteName: "group.easydigitaldownloads.EDDSalesTracker")!
}()

public final class Site: ManagedObject {
    
    // Attributes
    @NSManaged public private(set) var name: String?
    @NSManaged public private(set) var uid: String?
    @NSManaged public private(set) var url: String?
    @NSManaged public private(set) var currency: String?
    @NSManaged public private(set) var hasCommissions: NSNumber?
    @NSManaged public private(set) var hasFES: NSNumber?
    @NSManaged public private(set) var hasRecurring: NSNumber?
    @NSManaged public private(set) var hasReviews: NSNumber?
    @NSManaged public private(set) var hasLicensing: NSNumber?
    @NSManaged public private(set) var createdAt: NSDate?
    @NSManaged public private(set) var permissions: NSData?
    @NSManaged public private(set) var dashboardOrder: NSData?
    
    // Relationships
    @NSManaged private(set) var commissions: Set<Commission>
    @NSManaged private(set) var customers: Set<Customer>
    @NSManaged private(set) var discounts: Set<Discount>
    @NSManaged private(set) var products: Set<Product>
    @NSManaged private(set) var sales: Set<Sale>
    @NSManaged private(set) var subscriptions: Set<Subscription>

    var key: String = ""
    var token: String = ""
        
    var isCommissionActive: Bool {
        get {
            return Bool(hasCommissions!)
        }
    }
    
    var isFESActive: Bool {
        get {
            return Bool(hasFES!)
        }
    }
    
    var isRecurringActive: Bool {
        get {
            return Bool(hasRecurring!)
        }
    }
    
    var isReviewsActive: Bool {
        get {
            return Bool(hasReviews!)
        }
    }
    
    public static func insertIntoContext(moc: NSManagedObjectContext, uid: String, name: String, url: String, currency: String, hasCommissions: Bool, hasFES: Bool, hasRecurring: Bool, hasReviews: Bool, hasLicensing: Bool, permissions: NSData, dashboardOrder: NSData) -> Site {
        let site: Site = moc.insertObject()
        site.uid = uid
        site.name = name
        site.url = url
        site.currency = currency
        site.createdAt = NSDate()
        site.hasCommissions = hasCommissions
        site.hasFES = hasFES
        site.hasRecurring = hasRecurring
        site.hasReviews = hasReviews
        site.hasLicensing = hasLicensing
        site.permissions = permissions
        site.dashboardOrder = dashboardOrder
        return site
    }
    
    public static func predicateForDefaultSite() -> NSPredicate {
        guard let defaultSiteId = sharedDefaults.stringForKey("defaultSite") else {
            fatalError("No default site set")
        }
        return NSPredicate(format: "uid == %@", defaultSiteId)
    }
    
    public static func predicateForActiveSite() -> NSPredicate {
        guard let activeSiteId = sharedDefaults.stringForKey("activeSite") else {
            fatalError("No active site set")
        }
        return NSPredicate(format: "uid == %@", activeSiteId)
    }
    
    public static func defaultSite() -> Site {
        let appDelegate: AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let managedObjectContext = appDelegate.managedObjectContext
        
        let site = Site.fetchSingleObjectInContext(managedObjectContext) { request in
            request.predicate = self.predicateForDefaultSite()
            request.fetchLimit = 1
        }

        let auth = SSKeychain.accountsForService(site!.uid)
        let data = auth[0] as NSDictionary
        let acct = data.objectForKey("acct") as! String
        let password = SSKeychain.passwordForService(site!.uid, account: acct)
        
        site!.key = acct
        site!.token = password

        return site!
    }
    
    public static func hasActiveSite() -> Bool? {
        let appDelegate: AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let managedObjectContext = appDelegate.managedObjectContext

        let site = Site.fetchSingleObjectInContext(managedObjectContext) { request in
            request.predicate = self.predicateForActiveSite()
            request.fetchLimit = 1
        }
        
        if site == nil {
            return nil
        } else {
            return true
        }
    }
    
    public static func activeSite() -> Site {
        let appDelegate: AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        let managedObjectContext = appDelegate.managedObjectContext
        
        let site = Site.fetchSingleObjectInContext(managedObjectContext) { request in
            request.predicate = self.predicateForActiveSite()
            request.fetchLimit = 1
        }
        
        guard let site_ = site else {
            AppDelegate.sharedInstance.handleNoActiveSite()
            return Site()
        }
        
        let auth = SSKeychain.accountsForService(site_.uid)
        let data = auth[0] as NSDictionary
        let acct = data.objectForKey("acct") as! String
        let password = SSKeychain.passwordForService(site_.uid, account: acct)
        
        site_.key = acct
        site_.token = password
        
        return site_
    }
    
    public static func decodePermissionsForActiveSite() -> NSDictionary {
        let site = Site.activeSite()
        let permissions: NSDictionary = NSKeyedUnarchiver.unarchiveObjectWithData(site.permissions!)! as! NSDictionary
        return permissions
    }
    
    public static func getDashboardOrderForActiveSite() -> [Int] {
        let site = Site.activeSite()
        let dashboardOrder: [Int] = NSKeyedUnarchiver.unarchiveObjectWithData(site.dashboardOrder!)! as! [Int]
        return dashboardOrder
    }
    
    public static func fetchRecordForActiveSite(inContext moc: NSManagedObjectContext) -> Site {
        let site = Site.fetchSingleObjectInContext(moc) { request in
            request.predicate = self.predicateForActiveSite()
            request.fetchLimit = 1
        }
        return site!
    }
    
    public static func currencyFormat(number: NSNumber) -> String {
        return sharedNumberFormatter.stringFromNumber(number)!
    }
    
    public static func fetchSalesForActiveSite(inContext moc: NSManagedObjectContext) -> Set<Sale> {
        let site = Site.fetchRecordForActiveSite(inContext: moc)
        return site.sales
    }
    
    public static func fetchSubscriptionsForActiveSite(inContext moc: NSManagedObjectContext) -> Set<Subscription> {
        let site = Site.fetchRecordForActiveSite(inContext: moc)
        return site.subscriptions
    }
    
    public static func fetchProductsForActiveSite(inContext moc: NSManagedObjectContext) -> Set<Product> {
        let site = Site.fetchRecordForActiveSite(inContext: moc)
        return site.products
    }
    
    public static func fetchDiscountsForActiveSite(inContext moc: NSManagedObjectContext) -> Set<Discount> {
        let site = Site.fetchRecordForActiveSite(inContext: moc)
        return site.discounts
    }
    
    public static func fetchCustomersForActiveSite(inContext moc: NSManagedObjectContext) -> Set<Customer> {
        let site = Site.fetchRecordForActiveSite(inContext: moc)
        return site.customers
    }
    
    public static func fetchCommissionsForActiveSite(inContext moc: NSManagedObjectContext) -> Set<Commission> {
        let site = Site.fetchRecordForActiveSite(inContext: moc)
        return site.commissions
        
    }
    
    public static func fetchAll(inContext moc: NSManagedObjectContext) -> [Site]? {
        let results = Site.fetchInContext(moc)
        return results
    }
    
    public static func hasPermissionToViewReports() -> Bool {
        guard let data = Site.activeSite().permissions else {
            return false
        }
        
        guard let permissions = NSKeyedUnarchiver.unarchiveObjectWithData(data) else {
            return false
        }
        
        if permissions["view_shop_reports"] !== nil {
            return true
        } else {
            return false
        }
    }
    
    public static func hasPermissionToViewSensitiveData() -> Bool {
        guard let data = Site.activeSite().permissions else {
            return false
        }
        
        guard let permissions = NSKeyedUnarchiver.unarchiveObjectWithData(data) else {
            return false
        }
        
        if permissions["view_shop_sensitive_data"] !== nil {
            return true
        } else {
            return false
        }
    }
    
    public static func hasPermissionToManageDiscounts() -> Bool {
        guard let data = Site.activeSite().permissions else {
            return false
        }
        
        guard let permissions = NSKeyedUnarchiver.unarchiveObjectWithData(data) else {
            return false
        }
        
        if permissions["manage_shop_discounts"] !== nil {
            return true
        } else {
            return false
        }
    }
    
    public static func deleteSite(uid: String) {
        let productRequest = NSFetchRequest(entityName: "Product")
        productRequest.predicate = Product.defaultPredicate
        productRequest.returnsObjectsAsFaults = false
        let productDeleteRequest = NSBatchDeleteRequest(fetchRequest: productRequest)
        
        let customerRequest = NSFetchRequest(entityName: "Customer")
        customerRequest.predicate = Customer.defaultPredicate
        customerRequest.returnsObjectsAsFaults = false
        let customerDeleteRequest = NSBatchDeleteRequest(fetchRequest: customerRequest)
        
        let siteRequest = NSFetchRequest(entityName: "Site")
        siteRequest.predicate = NSPredicate(format: "uid == %@", uid)
        siteRequest.returnsObjectsAsFaults = false
        let siteDeleteRequest = NSBatchDeleteRequest(fetchRequest: siteRequest)
        
        do {
            try AppDelegate.sharedInstance.managedObjectContext.executeRequest(productDeleteRequest)
            try AppDelegate.sharedInstance.managedObjectContext.executeRequest(customerDeleteRequest)
            try AppDelegate.sharedInstance.managedObjectContext.executeRequest(siteDeleteRequest)
        } catch let error as NSError {
            print(error)
        }
    }
    
    public static func refreshActiveSite() -> Site {
        return Site.fetchSingleObjectInContext(AppDelegate.sharedInstance.managedObjectContext) { request in
            request.fetchLimit = 1
        }!
    }

}

extension Site: ManagedObjectType {
    
    public static var entityName: String {
        return "Site"
    }
    
    public static var defaultSortDescriptors: [NSSortDescriptor] {
        return [NSSortDescriptor(key: CreatedTimestampKey, ascending: false)]
    }
    
    public static var defaultPredicate: NSPredicate {
        return NSPredicate()
    }
    
}