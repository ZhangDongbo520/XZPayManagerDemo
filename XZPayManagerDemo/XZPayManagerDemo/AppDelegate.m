//
//  AppDelegate.m
//  XZPayManagerDemo
//
//  Created by Zeasn on 2018/1/26.
//  Copyright © 2018年 dreamer. All rights reserved.
//

#import "AppDelegate.h"

#import "XZPayManager.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    [[XZPayManager shareManager] xz_registerApp];//支付注册(微信需要在程序加载完成注册)
    
    return YES;
}

// 老版本接口
- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    return [[XZPayManager shareManager] xz_handleUrl:url];
}

// iOS 9.0 以后使用的新API接口
- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    return [[XZPayManager shareManager] xz_handleUrl:url];
}

// iOS 9.0 以前的接口
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    return [[XZPayManager shareManager] xz_handleUrl:url];
}


@end
