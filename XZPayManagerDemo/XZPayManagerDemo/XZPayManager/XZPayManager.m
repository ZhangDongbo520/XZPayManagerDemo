//
//  XZPayManager.m
//  XZPayManagerDemo
//
//  Created by Zeasn on 2018/1/26.
//  Copyright © 2018年 dreamer. All rights reserved.
//

#import "XZPayManager.h"

#import "WXApi.h"
#import <AlipaySDK/AlipaySDK.h>

#define XZTIP_CALLBACKURLISEMPTY @"url地址不能为空！"
#define XZTIP_ORDERINFOISEMPTY @"订单信息不能为空！"
#define XZTIP_PLEASEADDURLTYPE @"请先在Info.plist 添加 URL Type"
#define XZTIP_URLTYPE_SCHEME(name) [NSString stringWithFormat:@"请先在Info.plist 的 URL Type 添加 %@ 对应的 URL Scheme",name]

NSString * const ALIPAY_URLIDENTIFIER = @"zhifubao";
NSString * const WECHAT_URLIDENTIFIER = @"weixin";

@interface XZPayManager()<WXApiDelegate>

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
    }
    
    return YES;
}

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
        }
    }
}

- (void)xz_payWithOrderInfo:(id)orderInfo payCallBack:(XZPayCompleteCallBack)payCallBack {
    NSAssert(orderInfo, XZTIP_ORDERINFOISEMPTY);
    
    self.payCompleteCallBack = payCallBack;
    
    if ([orderInfo isKindOfClass:[PayReq class]]) {
        NSAssert(self.appSchemeDict[WECHAT_URLIDENTIFIER], XZTIP_URLTYPE_SCHEME(WECHAT_URLIDENTIFIER));
        [WXApi sendReq:(BaseReq *)orderInfo];
    } else if ([orderInfo isKindOfClass:[NSString class]]) {
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
    }
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

#pragma mark - get
- (NSMutableDictionary *)appSchemeDict {
    if (!_appSchemeDict) {
        _appSchemeDict = [NSMutableDictionary dictionary];
    }
    return _appSchemeDict;
}

@end
