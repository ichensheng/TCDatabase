//
//  AppDelegate.m
//  TCDatabase
//
//  Created by 陈 胜 on 16/5/17.
//  Copyright © 2016年 陈胜. All rights reserved.
//

#import "AppDelegate.h"
#import "TCDatabaseManager.h"
#import "TCDatabaseDAO.h"
#import "TCDynamicDAO.h"
#import "TCDatabase.h"

@interface AppDelegate () <TCDatabaseManagerDelegate>

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [TCDatabaseManager sharedInstance].delegate = self;
    [[TCDatabaseManager sharedInstance] openDatabase];
    
    TCDatabase *userDatabase = [TCDatabaseManager sharedInstance].userDatabase;
    
    TCDynamicDAO *testDAO = [TCDynamicDAO daoWithTable:@"test"
                                            atDatabase:userDatabase];
    
    [testDAO removeById:@"4D7F33D543AF45788E09451222167D0A"];
//    TCDatabaseDAO *userDAO = [TCDatabaseDAO daoWithTable:@"USER"
//                                              atDatabase:userDatabase];
//    
//    dispatch_async(TCDatabaseDAO.workQueue, ^{
//        NSDictionary *user1 = @{@"USER_CODE":@"zhangsan", @"USER_NAME":@"张三", @"USER_SEX":@"男"};
//        NSDictionary *user2 = @{@"USER_CODE":@"lisi", @"USER_NAME":@"李四", @"USER_SEX":@"男"};
//        NSDictionary *user3 = @{@"USER_CODE":@"wanger", @"USER_NAME":@"王二", @"USER_SEX":@"男"};
//        NSDictionary *user4 = @{@"USER_CODE":@"mazi", @"USER_NAME":@"麻子", @"USER_SEX":@"男"};
//        
//       [userDAO saveList:@[user1, user2, user3, user4]];
//        
//        TCSqlBean *sqlBean = [TCSqlBean instance];
//        [sqlBean pageNum:2 showNum:4];
//        [sqlBean selects:@"user_name,user_code"];
//        [sqlBean desc:@"user_code"];
//        NSLog(@"%@", [userDAO query:sqlBean]);
//    });
    
    
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark - TCDatabaseManagerDelegate

/**
 *  用户数据库路径
 *
 *  @return 数据库路径
 */
- (NSString *)userDbFilePath {
    NSURL *url = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    return [[url absoluteString] stringByAppendingString:@"user.db"];
}

/**
 *  用户表定义bundle名
 *
 *  @return bundle名
 */
- (NSString *)userTableBundleName {
    return @"user";
}

/**
 *  系统数据库路径
 *
 *  @return 数据库路径
 */
- (NSString *)systemDbFilePath {
    NSURL *url = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    return [[url absoluteString] stringByAppendingString:@"system.db"];
}

/**
 *  系统表定义bundle名
 *
 *  @return bundle名
 */
- (NSString *)systemTableBundleName {
    return @"system";
}

@end
