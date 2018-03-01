//
//  XZPayManager.h
//  XZPayManagerDemo
//
//  Created by Zeasn on 2018/1/26.
//  Copyright © 2018年 dreamer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 此处必须保证在Info.plist 中的 URL Types 的 Identifier 对应一致
UIKIT_EXTERN NSString * const ALIPAY_URLIDENTIFIER; //支付宝URL NAME
UIKIT_EXTERN NSString * const WECHAT_URLIDENTIFIER; //微信URL NAME
UIKIT_EXTERN NSString * const UNION_URLIDENTIFIER; //银联URL NAME


// 支付回调状态枚举
typedef NS_ENUM(NSInteger,XZPayStatusCode) {
    XZPayStatusSuccess,    //成功
    XZPayStatusFailure,      //失败
    XZPayStatusCancel       //取消
};

typedef void(^XZPayCompleteCallBack)(XZPayStatusCode errorCode, NSString *errorStr);

@interface XZPayManager : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

/**
 *  支付工具类
 *
 *  @return 单例
 */
+ (instancetype)shareManager;

/**
 *  支付跳转
 *
 *  @param url 跳转地址
 *  @return 是否跳转
 */
- (BOOL)xz_handleUrl:(NSURL *)url;

/**
 *   支付注册，需要在 didFinishLaunchingWithOptions 中调用
 */
- (void)xz_registerApp;

/**
 *  发起支付（支付宝和微信）
 *
 *  @param orderInfo  传入订单信息。 1.传入字符串，则对应跳转支付宝支付。  2.传入PayReq对象，则对应跳转微信支付
 *  @param payCallBack 支付结果回调
 */
- (void)xz_payWithOrderInfo:(id)orderInfo payCallBack:(XZPayCompleteCallBack)payCallBack;

/**
 *  发起支付（银联和ApplePay）
 *
 *  @param payVC  发起支付的控制器。
 *  @param orderInfo  传入订单信息。
 *  @param payCallBack 支付结果回调
 */
- (void)xz_payWithOrderInfo:(NSString *)orderInfo payVC:(UIViewController*)payVC  payCallBack:(XZPayCompleteCallBack)payCallBack;

@end
