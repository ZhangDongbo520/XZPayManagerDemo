//
//  XZPayManager.m
//  XZPayManagerDemo
//
//  Created by Zeasn on 2018/1/26.
//  Copyright © 2018年 dreamer. All rights reserved.
//

#import "XZPayManager.h"

#import "WXApi.h"//微信
#import <AlipaySDK/AlipaySDK.h>//支付宝
#import "UPPaymentControl.h"//银联
#import "UPAPayPlugin.h"//ApplePay

#define XZTIP_CALLBACKURLISEMPTY @"url地址不能为空！"
#define XZTIP_ORDERINFOISEMPTY @"订单信息不能为空！"
#define XZTIP_PLEASEADDURLTYPE @"请先在Info.plist 添加 URL Type"
#define XZTIP_URLTYPE_SCHEME(name) [NSString stringWithFormat:@"请先在Info.plist 的 URL Type 添加 %@ 对应的 URL Scheme",name]

NSString * const ALIPAY_URLIDENTIFIER = @"zhifubao";
NSString * const WECHAT_URLIDENTIFIER = @"weixin";
NSString * const UNION_URLIDENTIFIER = @"union";
NSString * const Apple_MerchantID = @"此处需换成从开发者帐号配置得到的MerchantID";

@interface XZPayManager()<WXApiDelegate, UPAPayPluginDelegate>

@property (nonatomic, strong) NSMutableDictionary *appSchemeDict;//存储支付宝和微信的urlScheme

@property (nonatomic, strong) XZPayCompleteCallBack payCompleteCallBack;

@end

@implementation XZPayManager

+ (instancetype)shareManager {
    static XZPayManager *payManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        payManager = [[self alloc] init];
    });
    return payManager;
}

#pragma mark - 支付注册
- (void)xz_registerApp {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Info" ofType:@"plist"];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    NSArray *urlTypes = dict[@"CFBundleURLTypes"];
    NSAssert(urlTypes, XZTIP_PLEASEADDURLTYPE);
    for (NSDictionary *urlTypeDict in urlTypes) {
        NSString *urlName = urlTypeDict[@"CFBundleURLName"];
        NSArray *urlSchemes = urlTypeDict[@"CFBundleURLSchemes"];
        NSString *urlScheme = [urlSchemes lastObject];
        NSAssert(urlSchemes.count, XZTIP_URLTYPE_SCHEME(urlName));
        //双向验证，Info.plist 与本文件中定义的ALIPAY_URLIDENTIFIER做比较，确保配置正确
        if ([urlName isEqualToString:WECHAT_URLIDENTIFIER]) {
            [self.appSchemeDict setValue:urlScheme forKey:WECHAT_URLIDENTIFIER];
            [WXApi registerApp:urlScheme];
        } else if ([urlName isEqualToString:ALIPAY_URLIDENTIFIER]) {
            [self.appSchemeDict setValue:urlScheme forKey:ALIPAY_URLIDENTIFIER];
        } else if ([urlName isEqualToString:UNION_URLIDENTIFIER]) {
            [self.appSchemeDict setValue:urlScheme forKey:UNION_URLIDENTIFIER];
        }
    }
}

#pragma mark - 支付跳转
- (BOOL)xz_handleUrl:(NSURL *)url {
    NSAssert(url, XZTIP_ORDERINFOISEMPTY);
    if ([url.host isEqualToString:@"pay"]) {
        [WXApi handleOpenURL:url delegate:self];
    } else if ([url.host isEqualToString:@"safepay"]) {
        //处理钱包或者独立快捷app支付跳回商户app携带的支付结果Url
        [[AlipaySDK defaultService] processOrderWithPaymentResult:url standbyCallback:^(NSDictionary *resultDic) {
            NSString *resultStatus = resultDic[@"resultStatus"];
            NSString *errStr = resultDic[@"memo"];
            XZPayStatusCode errorCode = XZPayStatusSuccess;
            switch (resultStatus.integerValue) {
                case 9000:// 成功
                    errorCode = XZPayStatusSuccess;
                    break;
                case 6001:// 取消
                    errorCode = XZPayStatusCancel;
                    break;
                default:
                    errorCode = XZPayStatusFailure;
                    break;
            }
            if (self.payCompleteCallBack) {
                self.payCompleteCallBack(errorCode,errStr);
            }
        }];
        // 授权跳转支付宝钱包进行支付，处理支付结果
        [[AlipaySDK defaultService] processAuth_V2Result:url standbyCallback:^(NSDictionary *resultDic) {
            // 解析 auth code
            NSString *result = resultDic[@"result"];
            NSString *authCode = nil;
            if (result.length > 0) {
                NSArray *resultArr = [result componentsSeparatedByString:@"&"];
                for (NSString *subResult in resultArr) {
                    if (subResult.length > 10 && [subResult hasPrefix:@"auth_code="]) {
                        authCode = [subResult substringFromIndex:10];
                        break;
                    }
                }
            }
            NSLog(@"授权结果 authCode = %@", authCode?:@"");
        }];
    } else if ([url.host isEqualToString:@"uppayresult"]) {
        [[UPPaymentControl defaultControl] handlePaymentResult:url completeBlock:^(NSString *code, NSDictionary *data) {
            XZPayStatusCode errorCode = XZPayStatusSuccess;
            NSString *errStr = @"";
            if ([code isEqualToString:@"success"]) {//交易成功
                errorCode = XZPayStatusSuccess;
                if (data != nil) {//交易成功返回的签名数据，需要发送到服务端进行验证
                    NSData *signData = [NSJSONSerialization dataWithJSONObject:data options:0 error:nil];
                    errStr = [[NSString alloc] initWithData:signData encoding:NSUTF8StringEncoding];
                }
            } else if ([code isEqualToString:@"fail"]) {//交易失败
                errorCode = XZPayStatusFailure;
                errStr = @"订单支付失败";
            } else if ([code isEqualToString:@"cancel"]) {//交易取消
                errorCode = XZPayStatusCancel;
                errStr = @"用户中途取消";
            }
            if (self.payCompleteCallBack) {
                self.payCompleteCallBack(errorCode,errStr);
            }
        }];
    }
    
    return YES;
}

#pragma mark - 发起支付
- (void)xz_payWithOrderInfo:(id)orderInfo payType:(XZPayType)payType payVC:(UIViewController*)payVC  payCallBack:(XZPayCompleteCallBack)payCallBack {
    NSAssert(orderInfo, XZTIP_ORDERINFOISEMPTY);
    
    self.payCompleteCallBack = payCallBack;
    
    if (payType == XZPayTypeWechat) {//微信支付
        NSAssert(self.appSchemeDict[WECHAT_URLIDENTIFIER], XZTIP_URLTYPE_SCHEME(WECHAT_URLIDENTIFIER));
        if ([orderInfo isKindOfClass:[PayReq class]]) {
            [WXApi sendReq:(BaseReq *)orderInfo];
        }
    } else if (payType == XZPayTypeAlipay) {//支付宝支付
        NSAssert(![orderInfo isEqualToString:@""], XZTIP_ORDERINFOISEMPTY);
        NSAssert(self.appSchemeDict[ALIPAY_URLIDENTIFIER], XZTIP_URLTYPE_SCHEME(ALIPAY_URLIDENTIFIER));
        [[AlipaySDK defaultService] payOrder:(NSString *)orderInfo fromScheme:(NSString *)self.appSchemeDict[ALIPAY_URLIDENTIFIER] callback:^(NSDictionary *resultDic) {
            NSString *resultStatus = resultDic[@"resultStatus"];
            NSString *errStr = resultDic[@"memo"];
            XZPayStatusCode errorCode = XZPayStatusSuccess;
            switch (resultStatus.integerValue) {
                case 9000:// 成功
                    errorCode = XZPayStatusSuccess;
                    break;
                case 6001:// 取消
                    errorCode = XZPayStatusCancel;
                    break;
                default:
                    errorCode = XZPayStatusFailure;
                    break;
            }
            if (self.payCompleteCallBack) {
                self.payCompleteCallBack(errorCode,errStr);
            }
        }];
    } else if (payType == XZPayTypeUnion) {//银联支付
        NSAssert(![orderInfo isEqualToString:@""], XZTIP_ORDERINFOISEMPTY);
        NSAssert(self.appSchemeDict[UNION_URLIDENTIFIER], XZTIP_URLTYPE_SCHEME(UNION_URLIDENTIFIER));
        [[UPPaymentControl defaultControl] startPay:(NSString *)orderInfo fromScheme:(NSString *)self.appSchemeDict[UNION_URLIDENTIFIER] mode:@"00" viewController:payVC];//00生产环境，01测试环境
    } else if (payType == XZPayTypeApplePay) {//ApplePay
        NSAssert(![orderInfo isEqualToString:@""], XZTIP_ORDERINFOISEMPTY);
        [UPAPayPlugin startPay:(NSString *)orderInfo mode:@"00" viewController:payVC delegate:self andAPMechantID:Apple_MerchantID];//00生产环境，01测试环境
    }
}

#pragma mark - 检查微信是否安装
- (BOOL)isWXAppInstalled {
    return [WXApi isWXAppInstalled];
}

#pragma mark - 检查云闪付(银联)是否安装
- (BOOL)isPaymentAppInstalled {
    return [[UPPaymentControl defaultControl] isPaymentAppInstalled];
}

#pragma mark - WXApiDelegate
- (void)onResp:(BaseResp *)resp {
    if ([resp isKindOfClass:[PayResp class]]) {
        XZPayStatusCode errorCode = XZPayStatusSuccess;
        NSString *errStr = resp.errStr;
        switch (resp.errCode) {
            case 0:
                errorCode = XZPayStatusSuccess;
                errStr = @"订单支付成功";
                break;
            case -1:
                errorCode = XZPayStatusFailure;
                errStr = resp.errStr;
                break;
            case -2:
                errorCode = XZPayStatusCancel;
                errStr = @"用户中途取消";
                break;
            default:
                errorCode = XZPayStatusFailure;
                errStr = resp.errStr;
                break;
        }
        if (self.payCompleteCallBack) {
            self.payCompleteCallBack(errorCode,errStr);
        }
    }
}

#pragma mark - UPAPayPluginDelegate
- (void)UPAPayPluginResult:(UPPayResult *)payResult {
    if ([payResult isKindOfClass:[UPPayResult class]]) {
        XZPayStatusCode errorCode = XZPayStatusSuccess;
        NSString *errStr = payResult.errorDescription;
        switch (payResult.paymentResultStatus) {
            case 0:
                errorCode = XZPayStatusSuccess;
                errStr = @"订单支付成功";
                break;
            case 1:
                errorCode = XZPayStatusFailure;
                errStr = @"订单支付失败";
                break;
            case 2:
                errorCode = XZPayStatusCancel;
                errStr = @"用户中途取消";
                break;
            default:
                errorCode = XZPayStatusFailure;
                errStr = payResult.errorDescription;
                break;
        }
        if (self.payCompleteCallBack) {
            self.payCompleteCallBack(errorCode,errStr);
        }
    }
}

#pragma mark - get
- (NSMutableDictionary *)appSchemeDict {
    if (!_appSchemeDict) {
        _appSchemeDict = [NSMutableDictionary dictionary];
    }
    return _appSchemeDict;
}

@end
