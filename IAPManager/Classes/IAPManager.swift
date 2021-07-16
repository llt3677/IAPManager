//
//  IAPManager.swift
//  iap_Example
//
//  Created by 李陆涛 on 2021/7/15.
//  Copyright © 2021 CocoaPods. All rights reserved.
//

import Foundation
import StoreKit

final public class IAPManager: NSObject {
    static public let shared = IAPManager()
    private var productId: String?
    // appdelegate中的闭包监听
    private var listenerComplete: ((_ success: Bool, _ trans: [String: String]?, _ errMSg: String?) -> Void)?
    // 购买时的闭包监听
    private var complete: ((_ success: Bool, _ trans: [String: String]?, _ errMSg: String?) -> Void)?
    
    private override init() {
        super.init()
        SKPaymentQueue.default().add(self)
    }
    
    deinit {
        SKPaymentQueue.default().remove(self)
    }
    
    /// 监听上次交易未完成的订单，在appdelegate的launch方法中调用，并处理
    /// 处理完成后请调用finished方法结束订单
    /// - Parameter complete: 完成回掉
    public func addListener(_ complete:@escaping (_ success: Bool, _ trans: [String: String]?, _ errMSg: String?) -> Void) {
        self.listenerComplete = complete
        _ = checkTransation()
    }
    
    /// 下单接口
    /// - Parameters:
    ///   - productIdentifier: 产品ID
    ///   - orderIdentifier: 订单ID
    ///   - userIdentifier: 用户ID
    ///   - complete: 完成回调
    public func buy(_ productIdentifier: String, orderIdentifier: String, userIdentifier: String, complete:@escaping (_ success: Bool, _ trans: [String: String]?, _ errMSg: String?) -> Void) {
        if checkTransation() {
            error("您有待完成的订单，正在恢复中，请稍后")
            return
        }
        
        IAPStoreManager.shared.userId = userIdentifier
        IAPStoreManager.shared.orderId = userIdentifier
        productId = productIdentifier
        self.complete = complete
        startRequest(productIdentifier)
    }
    
    /// 结束订单，请完成服务器验证后，务必调用此方法，结束订单
    /// - Parameter transation: 订单数据
    public func finished(_ transation: [String: String]) {
        guard let order_id = transation["order_id"] else { return }
        IAPStoreManager.shared.removeTransation(order_id)
    }
}

extension IAPManager {
    private func checkTransation() -> Bool {
        guard IAPStoreManager.shared.transations.isEmpty, let complete = listenerComplete else {
            return false
        }
        
        for transation in IAPStoreManager.shared.transations.values {
            complete(true, transation, nil)
        }
        return true
    }
    
    private func startRequest(_ productIdentifier: String) {
        let request = SKProductsRequest(productIdentifiers: [productIdentifier])
        request.delegate = self
        request.start()
    }
    
    private func error(_ message: String?) {
        complete?(false, nil, message)
    }
//    事务在队列中，用户已被计费。客户应完成交易。
    private func completeTransaction(_ transaction: SKPaymentTransaction) {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              let receiptData = NSData(contentsOf: receiptURL) else {
            error("支付凭证有误，请稍后再试")
            return
        }
        let receiptString = receiptData.base64EncodedString(options: .endLineWithLineFeed)
        var dict: [String: String] = [:]
        
        dict["user_id"] = IAPStoreManager.shared.userId
        dict["order_id"] = IAPStoreManager.shared.orderId
        dict["transaction_id"] = transaction.transactionIdentifier
        dict["product_id"] = transaction.payment.productIdentifier
        dict["receipt"] = receiptString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        
        IAPStoreManager.shared.addTransation(dict)
        complete?(true, dict, nil)
        
        IAPStoreManager.shared.userId = nil
        IAPStoreManager.shared.orderId = nil
    }
//    事务在添加到服务器队列之前被取消或失败。
    private func failedTransaction(_ transaction: SKPaymentTransaction) {
        error(transaction.error?.localizedDescription ?? "未知错误")
    }
//    事务已从用户的购买历史中恢复。客户应完成交易。
    private func restoreTransaction(_ transaction: SKPaymentTransaction) {
        print("重新购买")
    }
}

extension IAPManager: SKProductsRequestDelegate {
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        let products = response.products
        if products.isEmpty {
            error("没有商品")
            return
        }
        
        var product: SKProduct?
        products.forEach {
            if $0.productIdentifier == productId {
                product = $0
            }
        }
        
        guard let product = product else {
            error("没有找到对应商品")
            return
        }
        
        guard let orderId = IAPStoreManager.shared.orderId else {
            error("订单号为空")
            return
        }
        
        guard let userId = IAPStoreManager.shared.userId else {
            error("用户信息为空")
            return
        }
        
        let payment = SKMutablePayment(product: product)
        let applicationUsername = "\(userId),\(orderId)"
        payment.applicationUsername = applicationUsername
        
        SKPaymentQueue.default().add(payment)
    }
    
    public func requestDidFinish(_ request: SKRequest) {
    }
    
    public func request(_ request: SKRequest, didFailWithError error: Error) {
    }
}

extension IAPManager: SKPaymentTransactionObserver {
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchasing:
                print("事务正在添加到服务器队列中。。。。")
            case .purchased:
                completeTransaction(transaction)
                SKPaymentQueue.default().finishTransaction(transaction)
            case .failed:
                failedTransaction(transaction)
                SKPaymentQueue.default().finishTransaction(transaction)
            case .restored:
                restoreTransaction(transaction)
                SKPaymentQueue.default().finishTransaction(transaction)
            case .deferred:
                print("事务在队列中，但其最终状态是等待外部操作。。。。")
            @unknown default:
                print("不知道的情况")
            }
        }
    }
}
