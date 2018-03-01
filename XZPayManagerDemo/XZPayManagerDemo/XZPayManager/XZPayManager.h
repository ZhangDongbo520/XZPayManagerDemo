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
UIKIT_EXTERN NSString * const Apple_MerchantID; //ApplePay的MerchantID，需要到开发者帐号配置


// 支付回调状态枚举
typedef NS_ENUM(NSInteger,XZPayStatusCode) {
    XZPayStatusSuccess,    //成功
    XZPayStatusFailure,      //失败
    XZPayStatusCancel       //取消
};

// 支付类型
typedef NS_ENUM(NSInteger,XZPayType) {
    XZPayTypeAlipay,         //支付宝
    XZPayTypeWechat,      //微信
    XZPayTypeUnion,        //银联(云闪付)
    XZPayTypeApplePay    //ApplePay
};

typedef void(^XZPayCompleteCallBack)(XZPayStatusCode errorCode, NSString *errorStr);

@interface XZPayManager : NSObject


+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;


/*! @brief 支付工具类
 *
 *  @return 单例
 */
+ (instancetype)shareManager;


/*! @brief 支付注册，需要在 didFinishLaunchingWithOptions 中调用
 */
- (void)xz_registerApp;


/*! @brief 支付跳转
 *
 *  @param url 跳转地址
 *  @return 是否跳转
 */
- (BOOL)xz_handleUrl:(NSURL *)url;


/*! @brief 发起支付
 *
 *  @param orderInfo  传入订单信息。1.支付宝支付需传入订单字符串。  2.微信支付需传入PayReq对象。  3.云闪付(银联)和ApplePay需传入交易流水号tn字符串。
 *  @param payType  支付类型。
 *  @param payVC  发起支付的控制器。NOTE:银联和ApplePay必须传值，支付宝与微信支付无需传值
 *  @param payCallBack 支付结果回调
 */
- (void)xz_payWithOrderInfo:(id)orderInfo payType:(XZPayType)payType payVC:(UIViewController*)payVC  payCallBack:(XZPayCompleteCallBack)payCallBack;


/*! @brief 检查微信是否已被用户安装
 *
 * @return 微信已安装返回YES，未安装返回NO。
 */
- (BOOL)isWXAppInstalled;


/*! @brief 检查云闪付(银联)是否已被用户安装
 *
 * @return 云闪付(银联)已安装返回YES，未安装返回NO。
 */
- (BOOL)isPaymentAppInstalled;


@end
