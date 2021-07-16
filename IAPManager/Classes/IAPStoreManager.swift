//
//  IAPStoreManager.swift
//  iap_Example
//
//  Created by 李陆涛 on 2021/7/16.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import Foundation

private let kUSER_ID_KEY = "last_iap_user_id"
private let kORDER_ID_KEY = "last_iap_order_id"
private let kTRANSATIONS_KEY = "saved_iap_transations"

final class IAPStoreManager {
    static let shared = IAPStoreManager()
    private var _transations: [String: [String: String]] = [:]
    
    var transations: [String: [String: String]] {
        return _transations
    }
    
    var userId: String? {
        didSet {
            UserDefaults.standard.setValue(userId, forKey: kUSER_ID_KEY)
            UserDefaults.standard.synchronize()
        }
    }
    
    var orderId: String? {
        didSet {
            UserDefaults.standard.setValue(userId, forKey: kORDER_ID_KEY)
            UserDefaults.standard.synchronize()
        }
    }
    
    private init() {
        userId = UserDefaults.standard.string(forKey: kUSER_ID_KEY)
        orderId = UserDefaults.standard.string(forKey: kORDER_ID_KEY)
        _transations = UserDefaults.standard.dictionary(forKey: kTRANSATIONS_KEY)
            as? [String: [String: String]] ?? [:]
    }
}

extension IAPStoreManager {
    func addTransation(_ transation: [String: String]) {
        guard let order_id = transation["order_id"] else { return }
        _transations[order_id] = transation
        UserDefaults.standard.setValue(_transations, forKey: kTRANSATIONS_KEY)
        UserDefaults.standard.synchronize()
    }
    
    func removeTransation(_ order_id: String) {
        _transations.removeValue(forKey: order_id)
        UserDefaults.standard.setValue(_transations, forKey: kTRANSATIONS_KEY)
        UserDefaults.standard.synchronize()
    }
}
