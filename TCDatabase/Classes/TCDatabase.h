//
//  TCDatabase.h
//  TCDatabase
//
//  Created by 陈 胜 on 16/5/23.
//  Copyright © 2016年 陈胜. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FMDB.h"

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

@end
