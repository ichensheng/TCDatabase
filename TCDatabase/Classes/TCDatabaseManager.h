//
//  TCDatabaseManager.h
//  TCDatabase
//
//  Created by 陈 胜 on 16/6/13.
//  Copyright © 2016年 陈胜. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TCDatabase.h"
#import "TCDatabaseDAO.h"

@protocol TCDatabaseManagerDelegate;
@interface TCDatabaseManager : NSObject

@property (nonatomic, weak) id<TCDatabaseManagerDelegate> delegate;

@property (nonatomic, strong) TCDatabase *userDatabase;
@property (nonatomic, strong) TCDatabase *systemDatabase;

+ (instancetype)sharedInstance;

/**
 *  打开数据库
 */
- (void)openDatabase;

/**
 *  关闭数据库
 */
- (void)closeDatabase;

/**
 *  获取用户数据库访问对象
 *
 *  @param table 表名
 *
 *  @return TCDatabaseDAO
 */
- (TCDatabaseDAO *)databaseDAO:(NSString *)table;

/**
 *  获取系统数据库访问对象
 *
 *  @param table 表名
 *
 *  @return TCDatabaseDAO
 */
- (TCDatabaseDAO *)sysDatabaseDAO:(NSString *)table;

@end

@protocol TCDatabaseManagerDelegate <NSObject>

/**
 *  用户数据库路径
 *
 *  @return 数据库路径
 */
- (NSString *)userDbFilePath;

/**
 *  用户表定义bundle名
 *
 *  @return bundle名
 */
- (NSString *)userTableBundleName;

/**
 *  系统数据库路径
 *
 *  @return 数据库路径
 */
- (NSString *)systemDbFilePath;

/**
 *  系统表定义bundle名
 *
 *  @return bundle名
 */
- (NSString *)systemTableBundleName;

@end
