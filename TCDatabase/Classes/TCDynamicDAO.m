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
 *  @param table    表名
 *  @param database 数据库
 *
 *  @return DAO实例
 */
- (instancetype)initWithTable:(NSString *)table
                   atDatabase:(TCDatabase *)database {
    
    if (self = [super initWithTable:table atDatabase:database]) {
        self.dynamicTable = YES;
    }
    return self;
}

/**
 *  指定数据库和表构造DAO
 *
 *  @param table    表名
 *  @param database 数据库
 *
 *  @return DAO实例
 */
+ (instancetype)daoWithTable:(NSString *)table
                  atDatabase:(TCDatabase *)database {
    
    TCDynamicDAO *dao = [super daoWithTable:table atDatabase:database];
    dao.dynamicTable = YES;
    return dao;
}

/**
 *  如果data里没有主键或者主键对应的数据不存在则调用save，否则调用update方法
 *
 *  @param data 数据对象
 *
 *  @return 保存成功返回YES，否则返回NO
 */
- (BOOL)saveOrUpdate:(NSDictionary *)data {
    if ([self.database existsTable:self.table]) {
        return [super saveOrUpdate:data];
    }
    return NO;
}

/**
 *  批量保存数据，如果data里没有主键或者主键对应的数据不存在则调用save，否则调用update方法
 *
 *  @param dataList 数据数组
 *
 *  @return 保存成功返回YES，否则返回NO
 */
- (BOOL)saveOrUpdateList:(NSArray *)dataList {
    if ([self.database existsTable:self.table]) {
        return [super saveOrUpdateList:dataList];
    }
    return NO;
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
        [super update:data bySqlBean:sqlBean];
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
        [super update:data byId:pk];
    }
    return NO;
}

@end
