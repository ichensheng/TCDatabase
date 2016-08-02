//
//  TCDatabase.h
//  TCDatabase
//
//  Created by 陈 胜 on 16/5/23.
//  Copyright © 2016年 陈胜. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDB.h"

static NSString * const kDynamicKey = @"_PK_";  // 动态表主键

@interface TCDatabase : NSObject

@property (nonatomic, strong, readonly) FMDatabaseQueue *dbQueue;
@property (nonatomic, strong, readonly) NSMutableDictionary *tablesDef;

/**
 *  构造数据库对象，包含数据库访问队列、表定义、数据库加密key
 *
 *  @param path          数据文件路径
 *  @param tableBundle   表定义bundle
 *
 *  @return 数据库对象
 */
- (instancetype)initWithPath:(NSString *)path
                 tableBundle:(NSString *)tableBundle;

/**
 *  关闭数据库
 */
- (void)close;

/**
 *  根据表名判断该表在数据库里存不存在
 *
 *  @param tableName 表名
 *
 *  @return BOOL
 */
- (BOOL)existsTable:(NSString *)tableName;

/**
 *  自动检测扩展动态表
 *
 *  @param table 表名，会自动添加前缀
 *  @param data  动态表数据
 *  @param db    FMDatabase，防止嵌套
 */
- (void)checkDynamicTable:(NSString *)table
                     data:(NSDictionary *)data
                   withDb:(FMDatabase *)db;

@end
