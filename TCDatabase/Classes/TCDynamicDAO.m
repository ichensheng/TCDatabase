//
//  TCDynamicDAO.m
//  TCDatabase
//
//  Created by 陈 胜 on 16/8/2.
//  Copyright © 2016年 陈胜. All rights reserved.
//

#import "TCDynamicDAO.h"

@implementation TCDynamicDAO

/**
 *  指定数据库和表构造DAO
 *
 *  @param table        表名
 *  @param databaseName 数据库名
 *  @param provider     数据库对象provider
 *
 *  @return DAO实例
 */
- (instancetype)initWithTable:(NSString *)table
                 databaseName:(NSString *)databaseName
                     provider:(id<TCDatabaseProvider>)provider {
    
    if (self = [super initWithTable:table databaseName:databaseName provider:provider]) {
        self.dynamicTable = YES;
    }
    return self;
}

/**
 *  指定数据库和表构造DAO
 *
 *  @param table        表名
 *  @param databaseName 数据库名
 *  @param provider     数据库对象provider
 *
 *  @return DAO实例
 */
+ (instancetype)daoWithTable:(NSString *)table
                databaseName:(NSString *)databaseName
                    provider:(id<TCDatabaseProvider>)provider {
    
    TCDynamicDAO *dao = [super daoWithTable:table databaseName:databaseName provider:provider];
    dao.dynamicTable = YES;
    return dao;
}

/**
 *  按照条件更新数据
 *
 *  @param data    需要更新的字段和对应的值
 *  @param sqlBean 条件对象
 *
 *  @return 更新成功返回YES，否则返回NO
 */
- (BOOL)update:(NSDictionary *)data bySqlBean:(TCSqlBean *)sqlBean {
    if ([self.database existsTable:self.table]) {
        return [super update:data bySqlBean:sqlBean];
    }
    return NO;
}

/**
 *  按照主键更新数据
 *
 *  @param data 需要更新的字段和对应的值
 *  @param pk   主键
 *
 *  @return 更新成功返回YES，否则返回NO
 */
- (BOOL)update:(NSDictionary *)data byId:(NSString *)pk {
    if ([self.database existsTable:self.table]) {
        return [super update:data byId:pk];
    }
    return NO;
}

/**
 *  按条件删除数据
 *
 *  @param sqlBean 条件对象
 *
 *  @return 删除成功返回YES，否则返回NO
 */
- (BOOL)remove:(TCSqlBean *)sqlBean {
    if ([self.database existsTable:self.table]) {
        return [super remove:sqlBean];
    }
    return NO;
}

/**
 *  按主键删除数据
 *
 *  @param pk 主键
 *
 *  @return 删除成功返回YES，否则返回NO
 */
- (BOOL)removeById:(NSString *)pk {
    if ([self.database existsTable:self.table]) {
        return [super removeById:pk];
    }
    return NO;
}

/**
 *  按主键批量删除
 *
 *  @param pks 主键数组
 *
 *  @return 删除成功返回YES，否则返回NO
 */
- (BOOL)removeByIdList:(NSArray *)pks {
    if ([self.database existsTable:self.table]) {
        return [super removeByIdList:pks];
    }
    return NO;
}

/**
 *  自动匹配字典数据里的主键，然后删除
 *
 *  @param dataList 数据数组
 *
 *  @return 删除成功返回YES，否则返回NO
 */
- (BOOL)removeList:(NSArray *)dataList {
    if ([self.database existsTable:self.table]) {
        return [super removeList:dataList];
    }
    return NO;
}

@end
