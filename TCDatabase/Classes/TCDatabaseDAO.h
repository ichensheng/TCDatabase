//
//  TCDatabaseDAO.h
//  TCDatabase
//
//  Created by 陈 胜 on 16/5/23.
//  Copyright © 2016年 陈胜. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TCDatabase.h"

@class TCSqlBean;
@class UIColor;
@interface TCDatabaseDAO : NSObject

/**
 *  业务代码里如果没有自己的dispatch_queue_t可使用这个
 */
+ (dispatch_queue_t)workQueue;

/**
 *  指定数据库和表构造DAO
 *
 *  @param table    表名
 *  @param database 数据库
 *
 *  @return DAO实例
 */
- (instancetype)initWithTable:(NSString *)table
                   atDatabase:(TCDatabase *)database;

/**
 *  指定数据库和表构造DAO
 *
 *  @param table    表名
 *  @param database 数据库
 *
 *  @return DAO实例
 */
+ (instancetype)daoWithTable:(NSString *)table
                  atDatabase:(TCDatabase *)database;

/**
 *  添加单条数据，存在则覆盖，不存在则insert
 *
 *  注意：这里的做法是先删除原有的数据，然后重新insert一条新的记录，使用的是replace into方法，
 *  该方法适合每次都是全量数据保存的情况，非全量数据保存会丢失一些字段数据，
 *  如果需要局部更新记录请使用update:bySqlBean:或者update:byId:
 *
 *  @param data 数据对象
 *
 *  @return 保存成功返回YES，否则返回NO
 */
- (BOOL)save:(NSDictionary *)data;

/**
 *  添加多条数据，存在则覆盖，不存在则insert
 *
 *  注意：这里的做法是先删除原有的数据，然后重新insert一条新的记录，使用的是replace into方法，
 *  该方法适合每次都是全量数据保存的情况，非全量数据保存会丢失一些字段数据，
 *  如果需要局部更新记录请使用update:bySqlBean:或者update:byId:
 *
 *  @param dataList 数据数组
 *
 *  @return 保存成功返回YES，否则返回NO
 */
- (BOOL)saveList:(NSArray *)dataList;

/**
 *  如果data里没有主键或者主键对应的数据不存在则调用save，否则调用update方法
 *
 *  @param data 数据对象
 *
 *  @return 保存成功返回YES，否则返回NO
 */
- (BOOL)saveOrUpdate:(NSDictionary *)data;

/**
 *  批量保存数据，如果data里没有主键或者主键对应的数据不存在则调用save，否则调用update方法
 *
 *  @param dataList 数据数组
 *
 *  @return 保存成功返回YES，否则返回NO
 */
- (BOOL)saveOrUpdateList:(NSArray *)dataList;

/**
 *  按条件删除数据
 *
 *  @param sqlBean 条件对象
 *
 *  @return 删除成功返回YES，否则返回NO
 */
- (BOOL)remove:(TCSqlBean *)sqlBean;

/**
 *  按主键删除数据
 *
 *  @param pk 主键
 *
 *  @return 删除成功返回YES，否则返回NO
 */
- (BOOL)removeById:(NSString *)pk;

/**
 *  按主键批量删除
 *
 *  @param pks 主键数组
 *
 *  @return 删除成功返回YES，否则返回NO
 */
- (BOOL)removeByIdList:(NSArray *)pks;

/**
 *  自动匹配字典数据里的主键，然后删除
 *
 *  @param dataList 数据数组
 *
 *  @return 删除成功返回YES，否则返回NO
 */
- (BOOL)removeList:(NSArray *)dataList;

/**
 *  按照条件更新数据
 *
 *  @param data    需要更新的字段和对应的值
 *  @param sqlBean 条件对象
 *
 *  @return 更新成功返回YES，否则返回NO
 */
- (BOOL)update:(NSDictionary *)data bySqlBean:(TCSqlBean *)sqlBean;

/**
 *  按照主键更新数据
 *
 *  @param data 需要更新的字段和对应的值
 *  @param pk   主键
 *
 *  @return 更新成功返回YES，否则返回NO
 */
- (BOOL)update:(NSDictionary *)data byId:(NSString *)pk;

/**
 *  按条件查询
 *
 *  @param sqlBean 条件对象
 *
 *  @return 返回查询结果，失败返回nil
 */
- (NSArray *)query:(TCSqlBean *)sqlBean;

/**
 *  自定义sql语句查询
 *
 *  @param sql sql语句
 *
 *  @return 查询结果
 */
- (NSArray *)queryBySql:(NSString *)sql;

/**
 *  查询所有数据
 *
 *  @return 返回所有数据，失败返回nil
 */
- (NSArray *)queryAll;

/**
 *  按条件查询，返回第一条数据
 *
 *  @param sqlBean 条件对象
 *
 *  @return 返回第一条查询结果，不存在则返回nil
 */
- (NSDictionary *)queryOne:(TCSqlBean *)sqlBean;

/**
 *  按照数据主键查询
 *
 *  @param pk 主键
 *
 *  @return 返回查询结果，不存在则返回nil
 */
- (NSDictionary *)queryById:(NSString *)pk;

/**
 *  全文检索
 *
 *  @param keyword 检索关键字
 *  @param fields  高亮字段
 *  @param color   高亮颜色
 *
 *  @return 检索结果
 */
- (NSArray *)search:(NSString *)keyword
           snippets:(NSArray *)fields
     highlightColor:(UIColor *)color;

/**
 *  全文检索
 *
 *  @param keyword 检索关键字
 *
 *  @return 检索结果
 */
- (NSArray *)search:(NSString *)keyword;

@end


/**
 *  查询条件Bean
 */
@interface TCSqlBean : NSObject

@property (nonatomic, strong, readonly) NSMutableDictionary *dictionary;

/**
 *  静态方法获取TCSqlBean对象
 *
 *  @return 创建新的TCSqlBean对象
 */
+ (instancetype)instance;

/**
 *  增加'='过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)andEQ:(NSString *)field value:(NSString *)value;

/**
 *  增加'<>'过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)andNE:(NSString *)field value:(NSString *)value;

/**
 *  增加'>'过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)andGT:(NSString *)field value:(NSString *)value;

/**
 *  增加'>='过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)andGTE:(NSString *)field value:(NSString *)value;

/**
 *  增加'<'过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)andLT:(NSString *)field value:(NSString *)value;

/**
 *  增加'<='过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)andLTE:(NSString *)field value:(NSString *)value;

/**
 *  增加'like'过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)andLike:(NSString *)field value:(NSString *)value;

/**
 *  增加'not like'过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)andNotLike:(NSString *)field value:(NSString *)value;

/**
 *  增加'and'关系过滤项
 *
 *  @param field 字段
 *  @param op    sql操作符：=、like、<、>、<=、>=、<>等等
 *  @param value 值
 */
- (void)andWhere:(NSString *)field op:(NSString *)op value:(NSString *)value;

/**
 *  增加'in'过滤项
 *
 *  @param field  字段
 *  @param values 值
 */
- (void)andIn:(NSString *)field values:(NSArray *)values;

/**
 *  增加'not in'过滤项
 *
 *  @param field  字段
 *  @param values 值
 */
- (void)andNotIn:(NSString *)field values:(NSArray *)values;

/**
 *  增加'null'过滤
 *
 *  @param field 字段
 */
- (void)andNull:(NSString *)field;

/**
 *  增加'not null'过滤
 *
 *  @param field 字段
 */
- (void)andNotNull:(NSString *)field;

/**
 *  增加'or'关系过滤项
 *
 *  @param field 字段
 *  @param op    sql操作符：=、like、<、>、<=、>=、<>等等
 *  @param value 值
 */
- (void)orWhere:(NSString *)field op:(NSString *)op value:(NSString *)value;

/**
 *  增加'='过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)orEQ:(NSString *)field value:(NSString *)value;

/**
 *  增加'<>'过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)orNE:(NSString *)field value:(NSString *)value;

/**
 *  增加'>'过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)orGT:(NSString *)field value:(NSString *)value;

/**
 *  增加'>='过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)orGTE:(NSString *)field value:(NSString *)value;

/**
 *  增加'<'过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)orLT:(NSString *)field value:(NSString *)value;

/**
 *  增加'<='过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)orLTE:(NSString *)field value:(NSString *)value;

/**
 *  增加'like'过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)orLike:(NSString *)field value:(NSString *)value;

/**
 *  增加'not like'过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)orNotLike:(NSString *)field value:(NSString *)value;

/**
 *  增加'in'过滤项
 *
 *  @param field  字段
 *  @param values 值
 */
- (void)orIn:(NSString *)field values:(NSArray *)values;

/**
 *  增加'not in'过滤项
 *
 *  @param field  字段
 *  @param values 值
 */
- (void)orNotIn:(NSString *)field values:(NSArray *)values;

/**
 *  增加'null'过滤
 *
 *  @param field 字段
 */
- (void)orNull:(NSString *)field;

/**
 *  增加'not null'过滤
 *
 *  @param field 字段
 */
- (void)orNotNull:(NSString *)field;

/**
 *  分组条件
 *
 *  @param field 字段
 */
- (void)groupBy:(NSString *)field;

/**
 *  升序
 *
 *  @param field 字段
 */
- (void)asc:(NSString *)field;

/**
 *  倒序
 *
 *  @param field 字段
 */
- (void)desc:(NSString *)field;

/**
 *  指定获取哪几条数据
 *
 *  @param count  获取条数
 *  @param offset 偏移量
 */
- (void)limit:(NSUInteger)count offset:(NSUInteger)offset;

/**
 *  设置分页参数
 *
 *  @param pageNum 页码
 *  @param showNum 每页条数
 */
- (void)pageNum:(NSUInteger)pageNum showNum:(NSUInteger)showNum;

/**
 *  设置查询字段，逗号分隔
 *
 *  @param selects 查询字段
 */
- (void)selects:(NSString *)selects;

@end
