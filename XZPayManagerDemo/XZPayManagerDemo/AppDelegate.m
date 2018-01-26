//
//  AppDelegate.m
//  XZPayManagerDemo
//
//  Created by Zeasn on 2018/1/26.
//  Copyright © 2018年 dreamer. All rights reserved.
//

#import "AppDelegate.h"

#import "AppDelegate+XZPay.h"

#import "XZPayManager.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    [[XZPayManager shareManager] xz_registerApp];//支付注册(微信需要在程序加载完成注册)
    
    return YES;
}


@end
