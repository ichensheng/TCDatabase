//
//  TCDatabaseDAO.m
//  TCDatabase
//
//  Created by 陈 胜 on 16/5/23.
//  Copyright © 2016年 陈胜. All rights reserved.
//

#import "TCDatabaseDAO.h"
#import <UIKit/UIKit.h>

static NSString * const WHERE = @"_WHERE_";                // 过滤条件
static NSString * const GROUP = @"_GROUP_";                // 分组设置
static NSString * const ORDER = @"_ORDER_";                // 排序设置
static NSString * const PRE_VALUES = @"_PREVALUES_";       // 设置prepare sql变量信息
static NSString * const LIMIT_OFFSET = @"_LIMIT_OFFSET_";  // 获取条数
static NSString * const SELECTS = @"_SELECTS_";            // 查询字段，逗号分隔，不设置则查询所有字段

static NSString * const kDynamicTablePrefix = @"__DYNAMIC_TABLE_";  // 动态表前缀

@interface TCDatabaseDAO()

@property (nonatomic, copy, readwrite) NSString *table;
@property (nonatomic, copy) NSString *databaseName;
@property (nonatomic, strong) id<TCDatabaseProvider> provider;

@end

@implementation TCDatabaseDAO

/**
 *  默认是用户表空间
 *
 *  @return DAO实例
 */
- (instancetype)init {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
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
- (instancetype)initWithTable:(NSString *)table
                 databaseName:(NSString *)databaseName
                     provider:(id<TCDatabaseProvider>)provider {
    
    if (self = [super init]) {
        _table = [table uppercaseString];
        _databaseName = databaseName;
        _provider = provider;
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
    
    return [[self alloc] initWithTable:table
                          databaseName:databaseName
                              provider:provider];
}

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
- (BOOL)replace:(NSDictionary *)data {
    __block BOOL success = NO;
    [[self dbQueue] inDatabase:^(FMDatabase *db) {
        success = [self save:data withDb:db];
    }];
    return success;
}

/**
 *  添加单条数据，该方法实际调用的是saveOrUpdate:
 *
 *  @param data 数据对象
 *
 *  @return 保存成功返回YES，否则返回NO
 */
- (BOOL)save:(NSDictionary *)data {
    return [self saveOrUpdate:data];
}

/**
 *  添加多条数据，该方法实际调用的是saveOrUpdateList:
 *
 *  @param dataList 数据数组
 *
 *  @return 保存成功返回YES，否则返回NO
 */
- (BOOL)saveList:(NSArray *)dataList {
    return [self saveOrUpdateList:dataList];
}

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
- (BOOL)batchSave:(NSArray *)dataList {
    __block BOOL success = NO;
    [[self dbQueue] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        if (dataList.count > 0) {
            [self preprocess:db withData:dataList[0]];
        } else {
            [self preprocess:db];
        }
        NSMutableString *insertSqls = [[NSMutableString alloc] init];
        for (NSDictionary *data in dataList) {
            NSMutableArray *insertValues = [NSMutableArray array];
            NSString *insertSql = [self replaceSqlForData:data insertValues:insertValues batchSql:YES];
            [insertSqls appendString:insertSql];
            [insertSqls appendString:@";"];
        }
        success = [db executeStatements:insertSqls];
        [self printSQLLog:insertSqls];
    }];
    return success;
}

/**
 *  如果data里没有主键或者主键对应的数据不存在则调用save，否则调用update方法
 *
 *  @param data 数据对象
 *
 *  @return 保存成功返回YES，否则返回NO
 */
- (BOOL)saveOrUpdate:(NSDictionary *)data {
    __block BOOL success = NO;
    [[self dbQueue] inDatabase:^(FMDatabase *db) {
        success = [self saveOrUpdate:data withDb:db];
    }];
    return success;
}

/**
 *  批量保存数据，如果data里没有主键或者主键对应的数据不存在则调用save，否则调用update方法
 *
 *  @param dataList 数据数组
 *
 *  @return 保存成功返回YES，否则返回NO
 */
- (BOOL)saveOrUpdateList:(NSArray *)dataList {
    __block BOOL success = NO;
    [[self dbQueue] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        for (NSDictionary *data in dataList) {
            success = [self saveOrUpdate:data withDb:db];
            if (!success) {
                *rollback = YES;
                return;
            }
        }
    }];
    return success;
}

/**
 *  按条件删除数据
 *
 *  @param sqlBean 条件对象
 *
 *  @return 删除成功返回YES，否则返回NO
 */
- (BOOL)remove:(TCSqlBean *)sqlBean {
    __block BOOL success = NO;
    [[self dbQueue] inDatabase:^(FMDatabase *db) {
        [self preprocess:db];
        NSString *deleteSql = [self deleteSqlFromSqlBean:sqlBean];
        NSArray *preValues = [sqlBean.dictionary objectForKey:PRE_VALUES];
        success = [db executeUpdate:deleteSql withArgumentsInArray:preValues];
        [self printSQLLog:deleteSql values:preValues];
    }];
    return success;
}

/**
 *  按主键删除数据
 *
 *  @param pk 主键
 *
 *  @return 删除成功返回YES，否则返回NO
 */
- (BOOL)removeById:(NSString *)pk {
#if !DEBUG
    if (!pk || ![pk isKindOfClass:[NSString class]] || pk.length == 0) {
        return NO;
    }
#endif
    NSDictionary *tableDef = [[self tablesDef] objectForKey:[self.table uppercaseString]];
    NSString *keyName = [tableDef objectForKey:@"key"];
    if (!keyName && self.isDynamicTable) {
        keyName = kDynamicKey;
    }
    TCSqlBean *deleteSqlBean = [TCSqlBean instance];
    [deleteSqlBean andEQ:keyName value:pk];
    return [self remove:deleteSqlBean];
}

/**
 *  按主键批量删除
 *
 *  @param pks 主键数组
 *
 *  @return 删除成功返回YES，否则返回NO
 */
- (BOOL)removeByIdList:(NSArray *)pks {
    if (!pks || [pks count] == 0) {
        return NO;
    }
    NSDictionary *tableDef = [[self tablesDef] objectForKey:[self.table uppercaseString]];
    NSString *keyName = [tableDef objectForKey:@"key"];
    if (!keyName && self.isDynamicTable) {
        keyName = kDynamicKey;
    }
    TCSqlBean *deleteSqlBean = [TCSqlBean instance];
    [deleteSqlBean andIn:keyName values:pks];
    return [self remove:deleteSqlBean];
}

/**
 *  自动匹配字典数据里的主键，然后删除
 *
 *  @param dataList 数据数组
 *
 *  @return 删除成功返回YES，否则返回NO
 */
- (BOOL)removeList:(NSArray *)dataList {
    if (!dataList || [dataList count] == 0) {
        return YES;
    }
    NSDictionary *tableDef = [[self tablesDef] objectForKey:[self.table uppercaseString]];
    NSString *keyName = [tableDef objectForKey:@"key"];
    NSMutableArray *pks = [NSMutableArray array];
    for (NSDictionary *data in dataList) {
        NSString *pk = data[keyName];
        if (pk && pk.length > 0) {
            [pks addObject:pk];
        }
    }
    return [self removeByIdList:pks];
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
    __block BOOL success = NO;
    [[self dbQueue] inDatabase:^(FMDatabase *db) {
        success = [self update:data bySqlBean:sqlBean withDb:db];
    }];
    return success;
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
    __block BOOL success = NO;
    [[self dbQueue] inDatabase:^(FMDatabase *db) {
        success = [self update:data byId:pk withDb:db];
    }];
    return success;
}

/**
 *  按条件查询
 *
 *  @param sqlBean 条件对象
 *
 *  @return 返回查询结果，失败返回nil，不存在数据则返回空数组
 */
- (NSArray *)query:(TCSqlBean *)sqlBean {
    if (!sqlBean) { // 如果sqlBean为空则取所有数据
        sqlBean = [TCSqlBean instance];
    }
    __block NSArray *results = nil;
    [[self dbQueue] inDatabase:^(FMDatabase *db) {
        results = [self query:sqlBean withDb:db];
    }];
    return results;
}

/**
 *  自定义sql语句查询
 *
 *  @param sql sql语句
 *
 *  @return 查询结果
 */
- (NSArray *)queryBySql:(NSString *)sql {
    __block NSMutableArray *results = [NSMutableArray array];
    [[self dbQueue] inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:sql];
        while ([rs next]) {
            [results addObject:[self replaceNull:[rs resultDictionary]]];
        }
        [rs close];
    }];
    return results;
}

/**
 *  查询所有数据
 *
 *  @return 返回所有数据，失败返回nil
 */
- (NSArray *)queryAll {
    return [self query:nil];
}

/**
 *  按条件查询，返回第一条数据
 *
 *  @param sqlBean 条件对象
 *
 *  @return 返回第一条查询结果，不存在则返回nil
 */
- (NSDictionary *)queryOne:(TCSqlBean *)sqlBean {
    NSArray *results = [self query:sqlBean];
    if (results && results.count > 0) {
        return results[0];
    }
    return nil;
}

/**
 *  按照数据主键查询
 *
 *  @param pk 主键
 *
 *  @return 返回查询结果，不存在则返回nil
 */
- (NSDictionary *)queryById:(NSString *)pk {
    __block NSDictionary *data = nil;
    [[self dbQueue] inDatabase:^(FMDatabase *db) {
        data = [self queryById:pk withDb:db];
    }];
    return data;
}

/**
 *  按照数据主键数组查询
 *
 *  @param pks 主键数组
 *
 *  @return 返回查询结果，不存在则返回nil
 */
- (NSArray *)queryByIdList:(NSArray *)pks {
    NSDictionary *tableDef = [[self tablesDef] objectForKey:[self.table uppercaseString]];
    NSString *keyName = [tableDef objectForKey:@"key"];
    if (!keyName && self.isDynamicTable) {
        keyName = kDynamicKey;
    }
    TCSqlBean *sqlBean = [TCSqlBean instance];
    [sqlBean andIn:keyName values:pks];
    return [self query:sqlBean];
}

/**
 *  给定条件数据的条数
 *
 *  @param sqlBean 条件
 *
 *  @return 数据条数
 */
- (NSInteger)count:(TCSqlBean *)sqlBean {
    __block NSInteger count = 0;
    [[self dbQueue] inDatabase:^(FMDatabase *db) {
        NSArray *preValues = [sqlBean.dictionary objectForKey:PRE_VALUES];
        FMResultSet *rs = [db executeQuery:[self countSqlFromSqlBean:sqlBean] withArgumentsInArray:preValues];
        if (rs) {
            while ([rs next]) {
                NSDictionary *dict = [rs resultDictionary];
                count = [dict[@"count"] integerValue];
            }
            [rs close];
        }
    }];
    return count;
}

/**
 *  全文检索
 *
 *  @param keyword 检索关键字
 *  @param fields  高亮字段
 *  @param color   高亮颜色
 *SELECT * FROM table WHERE table MATCH 'A:cat OR C:cat'
 http://www.sqlite.org/fts3.html#termprefix
 http://www.helplib.net/s/sqlite/9/17.shtml
 *  @return 检索结果
 */
- (NSArray *)search:(NSString *)keyword
           snippets:(NSArray *)fields
     highlightColor:(UIColor *)color {
    
#if (TARGET_IPHONE_SIMULATOR)
    NSLog(@"模拟器不支持全文检索");
    return @[];
#else
    NSMutableArray *mutableFields = [NSMutableArray array];
    if (fields.count > 0) {
        for (NSString *field in fields) {
            [mutableFields addObject:[field uppercaseString]];
        }
        fields = mutableFields;
    }
    __block NSMutableArray *searchResults = [NSMutableArray array];
    NSDictionary *tableDefinition = [self tablesDef][self.table];
    if (tableDefinition[@"fts"]) {
        [[self dbQueue] inDatabase:^(FMDatabase *db) {
            [self preprocess:db];
            NSString *searchSql = [NSString stringWithFormat:@"SELECT (SELECTS) FROM %@ WHERE ", self.table];
            NSMutableString *matchSql = [[NSMutableString alloc] init];
            [matchSql appendString:self.table];
            [matchSql appendString:@" match '"];
            [matchSql appendString:keyword];
            [matchSql appendString:@"'"];
            NSString *selects = [self selectsForFtsFields:mutableFields];
            searchSql = [searchSql stringByReplacingOccurrencesOfString:@"(SELECTS)" withString:selects];
            searchSql = [searchSql stringByAppendingString:matchSql];
            FMResultSet *rs = [db executeQuery:searchSql];
            while ([rs next]) {
                [searchResults addObject:[self replaceNull:[rs resultDictionary] snippets:mutableFields highlightColor:color]];
            }
            [rs close];
            [self printSQLLog:searchSql];
        }];
    } else {
        NSLog(@"表'%@'不支持全文检索", self.table);
    }
    return searchResults;
#endif
}

/**
 *  全文检索
 *
 *  @param keyword 检索关键字
 *  @param fields  高亮字段
 *
 *  @return 检索结果
 */
- (NSArray *)search:(NSString *)keyword {
    return [self search:keyword snippets:nil highlightColor:nil];
}

#pragma mark - Private Methods

- (NSString *)table {
    if (!_table) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"TCDatabaseDAO实例需要设置表名"
                                     userInfo:nil];
    }
    return _table;
}

/**
 *  生成全文检索查询字段部分sql
 *
 *  @param fields 查询的字段，需要高亮
 *
 *  @return selects
 */
- (NSString *)selectsForFtsFields:(NSArray *)fields {
    if (!fields || fields.count == 0) {
        return @"*";
    }
    NSMutableString *selects = [[NSMutableString alloc] init];
    NSDictionary *tableDef = [[self tablesDef] objectForKey:[self.table uppercaseString]];
    NSArray *cols = tableDef[@"cols"];
    NSInteger count = cols.count;
    for (NSInteger i = 0; i < count; i++) {
        NSDictionary *col = cols[i];
        NSString *fieldName = col[@"name"];
        if ([fields containsObject:fieldName]) {
            NSString *snippet = [NSString stringWithFormat:@"snippet(%@, '[', ']', '...') as %@", self.table, fieldName];
            [selects appendString:snippet];
        } else {
            [selects appendString:fieldName];
        }
        if (i != count - 1) {
            [selects appendString:@", "];
        }
    }
    return selects;
}

/**
 *  替换null为空字符串，并且高亮
 *
 *  @param resultDict 数据库记录
 *  @param color      高亮颜色记录
 *
 *  @return 过滤了null之后的记录
 */
- (NSDictionary *)replaceNull:(NSDictionary *)result
                     snippets:(NSArray *)fields
               highlightColor:(UIColor *)color {
    
    NSMutableDictionary *mutableResultDict = [NSMutableDictionary dictionary];
    NSString *uppercaseKey = nil;
    id fieldValue = nil;
    for (NSString *key in result) {
        fieldValue = result[key];
        uppercaseKey = [key uppercaseString];
        if ([fieldValue isKindOfClass:[NSNull class]]) {
            mutableResultDict[uppercaseKey] = @""; // null替换为空字符串，使得转换成模型时不崩溃
        } else {
            if ([fields containsObject:uppercaseKey]) {
                mutableResultDict[uppercaseKey] = [self highlightString:fieldValue withColor:color];
            } else {
                mutableResultDict[uppercaseKey] = fieldValue;
            }
        }
    }
    return mutableResultDict;
}

/**
 *  生成带属性的字符串
 *
 *  @param resultText 搜索结果
 *  @param color      高亮颜色
 *
 *  @return 带属性的字符串
 */
- (NSAttributedString *)highlightString:(NSString *)resultText
                              withColor:(UIColor *)color {
    
    NSMutableAttributedString *resultAttributedString = [[NSMutableAttributedString alloc] init];
    NSUInteger prevLocation = 0;
    NSString *pattern = @"\\[[^\\[\\]]+\\]";
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    NSRange range = NSMakeRange(0, [resultText length]);
    NSArray *matchResults = [expression matchesInString:resultText options:0 range:range];
    
    if (matchResults.count > 0) {
        for (NSTextCheckingResult *matchResult in matchResults) {
            NSRange range = [matchResult rangeAtIndex:0];
            
            if (range.location > prevLocation) {
                NSRange plainTextRange = NSMakeRange(prevLocation, range.location - prevLocation);
                NSAttributedString *plainText = [[NSAttributedString alloc] initWithString:[resultText substringWithRange:plainTextRange]];
                [resultAttributedString appendAttributedString:plainText];
            }
            
            NSRange highlightTextRange = NSMakeRange(range.location + 1, range.length - 2);
            NSAttributedString *highlightText = [[NSAttributedString alloc] initWithString:[resultText substringWithRange:highlightTextRange] attributes:@{NSBackgroundColorAttributeName: color}];
            [resultAttributedString appendAttributedString:highlightText];
            
            prevLocation = range.location + range.length;
        }
        
        if ([resultText length] > prevLocation) {
            NSRange plainTextRange = NSMakeRange(prevLocation, [resultText length] - prevLocation);
            NSAttributedString *plainText = [[NSAttributedString alloc] initWithString:[resultText substringWithRange:plainTextRange]];
            [resultAttributedString appendAttributedString:plainText];
        }
    } else {
        resultAttributedString = [[NSMutableAttributedString alloc] initWithString:resultText];
    }
    
    return resultAttributedString;
}

/**
 *  替换掉查询结果的null
 *
 *  @param resultDict 数据库记录
 *
 *  @return 过滤了null之后的记录
 */
- (NSDictionary *)replaceNull:(NSDictionary *)resultDict {
    return [self replaceNull:resultDict snippets:nil highlightColor:nil];
}

/**
 *  使用指定FMDatabase对象保存数据
 *
 *  @param data 数据对象
 *  @param db   FMDatabase对象
 *
 *  @return 保存成功返回YES，否则返回NO
 */
- (BOOL)save:(NSDictionary *)data withDb:(FMDatabase *)db {
    [self preprocess:db withData:data];
    NSMutableArray *insertValues = [NSMutableArray array];
    NSString *insertSql = [self replaceSqlForData:data insertValues:insertValues batchSql:NO];
    BOOL success = [db executeUpdate:insertSql withArgumentsInArray:insertValues];
    [self printSQLLog:insertSql values:insertValues];
    return success;
}

/**
 *  使用指定FMDatabase对象更新数据
 *
 *  @param data    数据对象
 *  @param sqlBean 条件对象
 *  @param db      FMDatabase对象
 *
 *  @return 更新成功返回YES，失败返回NO
 */
- (BOOL)update:(NSDictionary *)data bySqlBean:(TCSqlBean *)sqlBean withDb:(FMDatabase *)db {
    BOOL success = NO;
    [self preprocess:db withData:data];
    NSString *where = [sqlBean.dictionary objectForKey:WHERE];
    NSMutableArray *updateValues = [NSMutableArray array];
    NSString *updateSql = [self updateSqlForData:data updateValues:updateValues];
    if (updateValues.count == 0) {
        NSLog(@"没有需要更新的值");
        return YES;
    }
    if (where.length > 0) {
        updateSql = [NSString stringWithFormat:@"%@ where 1=1%@", updateSql, where];
    }
    [updateValues addObjectsFromArray:[sqlBean.dictionary objectForKey:PRE_VALUES]];
    success = [db executeUpdate:updateSql withArgumentsInArray:updateValues];
    [self printSQLLog:updateSql values:updateValues];
    return success;
}

/**
 *  使用指定FMDatabase对象保存或更新数据
 *
 *  @param data 数据对象
 *  @param db   FMDatabase对象
 *
 *  @return 成功返回YES，失败返回NO
 */
- (BOOL)saveOrUpdate:(NSDictionary *)data withDb:(FMDatabase *)db {
    NSDictionary *tableDef = [[self tablesDef] objectForKey:[self.table uppercaseString]];
    NSString *keyName = [[tableDef objectForKey:@"key"] uppercaseString];
    BOOL update = NO; // 是否是update
    if (data[keyName]) {
        if ([self queryById:data[keyName] withDb:db]) {
            update = YES;
        }
    }
    
    BOOL success = NO;
    if (update) {
        success = [self update:data byId:data[keyName] withDb:db];
    } else {
        success = [self save:data withDb:db];
    }
    return success;
}

/**
 *  按照数据主键查询
 *
 *  @param pk 主键
 *
 *  @return 返回查询结果，不存在则返回nil
 */

/**
 *  按照数据主键查询
 *
 *  @param pk 主键
 *  @param db FMDatabase对象
 *
 *  @return 返回查询结果，不存在则返回nil
 */
- (NSDictionary *)queryById:(NSString *)pk withDb:(FMDatabase *)db {
#if !DEBUG
    if (!pk || ![pk isKindOfClass:[NSString class]] || pk.length == 0) {
        return nil;
    }
#endif
    NSDictionary *tableDef = [[self tablesDef] objectForKey:[self.table uppercaseString]];
    NSString *keyName = [tableDef objectForKey:@"key"];
    if (!keyName && self.isDynamicTable) {
        keyName = kDynamicKey;
    }
    TCSqlBean *querySqlBean = [TCSqlBean instance];
    [querySqlBean andEQ:keyName value:pk];
    NSArray *results = [self query:querySqlBean withDb:db];
    if (results && results.count > 0) {
        return [results firstObject];
    }
    return nil;
}

/**
 *  按条件查询
 *
 *  @param sqlBean 条件对象
 *  @param db FMDatabase对象
 *
 *  @return 返回查询结果，失败返回nil，不存在数据则返回空数组
 */
- (NSArray *)query:(TCSqlBean *)sqlBean withDb:(FMDatabase *)db {
    NSMutableArray *results = [NSMutableArray array];
    [self preprocess:db];
    NSArray *preValues = [sqlBean.dictionary objectForKey:PRE_VALUES];
    NSString *selectSql = [self selectSqlFromSqlBean:sqlBean];
    FMResultSet *rs = [db executeQuery:selectSql withArgumentsInArray:preValues];
    [self printSQLLog:selectSql values:preValues];
    if (rs) {
        while ([rs next]) {
            [results addObject:[self replaceNull:[rs resultDictionary]]];
        }
        [rs close];
    } else { // 失败
        results = nil;
    }
    return results;
}

/**
 *  按照主键更新数据
 *
 *  @param data 需要更新的字段和对应的值
 *  @param pk   主键
 *  @param db FMDatabase对象
 *
 *  @return 更新成功返回YES，否则返回NO
 */
- (BOOL)update:(NSDictionary *)data byId:(NSString *)pk withDb:(FMDatabase *)db {
#if !DEBUG
    if (!pk || ![pk isKindOfClass:[NSString class]] || pk.length == 0) {
        return NO;
    }
#endif
    NSDictionary *tableDef = [[self tablesDef] objectForKey:[self.table uppercaseString]];
    NSString *keyName = [tableDef objectForKey:@"key"];
    if (!keyName && self.isDynamicTable) {
        keyName = kDynamicKey;
    }
    TCSqlBean *updateSqlBean = [TCSqlBean instance];
    [updateSqlBean andEQ:keyName value:pk];
    return [self update:data bySqlBean:updateSqlBean withDb:db];
}

/**
 *  预处理
 *
 *  @param db   FMDatabase
 *  @param data 动态数据对象
 */
- (void)preprocess:(FMDatabase *)db withData:(NSDictionary *)data {
    if (!db.shouldCacheStatements) {
        [db setShouldCacheStatements:YES];
    }
    if (self.isDynamicTable) {
        [[self database] checkDynamicTable:self.table data:data withDb:db];
    }
}

/**
 *  预处理
 *
 *  @param db   FMDatabase
 */
- (void)preprocess:(FMDatabase *)db {
    [self preprocess:db withData:nil];
}

/**
 *  生成replace into语句
 *
 *  @param data    需要插入的数据
 *  @param batch   调用executeStatements则设为YES
 *
 *  @return 插入语句
 */
- (NSString *)replaceSqlForData:(NSDictionary *)data insertValues:(NSMutableArray *)insertValues batchSql:(BOOL)batch {
    NSDictionary *tableDef = [[self tablesDef] objectForKey:[self.table uppercaseString]];
    NSArray *columns = [tableDef objectForKey:@"columnNames"];
    NSMutableDictionary *mutableData = [self modifyData:data byColumns:columns];
    NSString *keyName = [tableDef objectForKey:@"key"];
    NSString *key = [mutableData objectForKey:keyName];
    if (!key) { // 主键不存在则生成主键
        key = [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
        [mutableData setObject:key forKey:keyName];
    }
    
    NSMutableString *insertKey = [NSMutableString string];
    NSMutableString *insertValuesString = [[NSMutableString alloc] init];
    for (NSInteger i = 0; i < columns.count; i++) {
        NSString *columnName =  columns[i];
        NSString *value = [mutableData objectForKey:columnName];
        
        /**
         * 忽略无数据column
         */
        if (!value) {
            continue;
        }
        
        value = [self cleanColumnValue:value];
        
        if (insertKey.length > 0) {
            [insertKey appendString:@","];
            [insertValuesString appendString:@","];
        }
        
        [insertKey appendString:columnName];
        if (batch) {
            [insertValuesString appendString:[NSString stringWithFormat:@"'%@'", value]];
        } else {
            [insertValuesString appendString:@"?"];
            [insertValues addObject:value];
        }
    }
    
    return [NSString stringWithFormat:@"insert or replace into %@(%@) values(%@)", self.table, insertKey, insertValuesString];
}

/**
 *  生成删除语句
 *
 *  @param sqlBean 条件
 *
 *  @return 删除语句
 */
- (NSString *)deleteSqlFromSqlBean:(TCSqlBean *)sqlBean {
    NSString *where = [sqlBean.dictionary objectForKey:WHERE] ?: @"";
    return [NSString stringWithFormat:@"delete from %@ where 1=1%@", self.table, where];
}

/**
 *  生成更新语句
 *
 *  @param sqlBean 条件
 *  @param updateValues
 *
 *  @return 更新语句
 */
- (NSString *)updateSqlForData:(NSDictionary *)data updateValues:(NSMutableArray *)updateValues {
    NSDictionary *tableDef = [[self tablesDef] objectForKey:[self.table uppercaseString]];
    NSArray *columns = [tableDef objectForKey:@"columnNames"];
    NSMutableDictionary *mutableData = [self modifyData:data byColumns:columns];
    NSString *keyName = [tableDef objectForKey:@"key"];
    NSMutableString *updateKey = [NSMutableString string];
    for (NSInteger i = 0; i < columns.count; i++) {
        NSString *columnName =  columns[i];
        NSString *value = [mutableData objectForKey:columnName];
        // 忽略无数据column
        if (!value) {
            continue;
        }

        value = [self cleanColumnValue:value];
        
        if (![columnName isEqualToString:keyName]) { // 忽略主键
            if (updateKey.length > 0) {
                [updateKey appendString:@","];
            }
            [updateKey appendFormat:@"%@=?", columnName];
            [updateValues addObject:value];
        }
    }
    return [NSString stringWithFormat:@"update %@ set %@", self.table, updateKey];
}

/**
 * 处理下需要保存的字段值
 */
- (NSString *)cleanColumnValue:(NSString *)value {
    if ([value isKindOfClass:[NSString class]] && [value containsString:@"'"]) { // 处理单引号
        value = [value stringByReplacingOccurrencesOfString:@"'" withString:@"\""];
    } else if ([value isKindOfClass:[NSDictionary class]] || [value isKindOfClass:[NSArray class]]) { // 对象序列化
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:value
                                                           options:NSJSONWritingPrettyPrinted
                                                             error:&error];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData
                                                     encoding:NSUTF8StringEncoding];
        if (error) {
            NSLog(@"%@", error);
        } else {
            value = jsonString;
        }
    }
    return value;
}

/**
 *  生成查询语句
 *
 *  @param sqlBean 条件
 *
 *  @return 查询语句
 */
- (NSString *)selectSqlFromSqlBean:(TCSqlBean *)sqlBean {
    NSString *selects = [sqlBean.dictionary objectForKey:SELECTS];
    if (!selects || selects.length == 0) {
        selects = @"*";
    }
    NSMutableString *selectSql = [NSMutableString stringWithFormat:@"select %@ from %@ where 1=1", selects, self.table];
    NSString *where = [sqlBean.dictionary objectForKey:WHERE];
    if (where && where.length > 0) {
        [selectSql appendString:where];
    }
    NSString *groupBy = [sqlBean.dictionary objectForKey:GROUP];
    if (groupBy && groupBy.length > 0) {
        [selectSql appendString:groupBy];
    }
    NSString *order = [sqlBean.dictionary objectForKey:ORDER];
    if (order && order.length > 0) {
        [selectSql appendString:order];
    }
    NSString *limitOffset = [sqlBean.dictionary objectForKey:LIMIT_OFFSET];
    if (limitOffset && limitOffset.length > 0) {
        [selectSql appendString:limitOffset];
    }
    return selectSql;
}

/**
 *  生成查询数据总量的语句
 *
 *  @param sqlBean 条件
 *
 *  @return 查询语句
 */
- (NSString *)countSqlFromSqlBean:(TCSqlBean *)sqlBean {
    NSMutableString *countSql = [NSMutableString stringWithFormat:@"select count(*) as count from %@ where 1=1", self.table];
    if (!sqlBean) {
        return countSql;
    }
    NSString *where = [sqlBean.dictionary objectForKey:WHERE];
    if (where && where.length > 0) {
        [countSql appendString:where];
    }
    return countSql;
}

/**
 *  把数据里面字段key都改成大写
 *
 *  @param data    数据
 *  @param columns 字段名
 *
 *  @return 返回新的数据
 */
- (NSMutableDictionary *)modifyData:(NSDictionary *)data byColumns:(NSArray *)columns {
    NSMutableDictionary *newData = [NSMutableDictionary dictionary];
    for (NSString *key in data) {
        NSString *uppercaseKey = [key uppercaseString];
        if ([columns containsObject:uppercaseKey]) { // 存在该字段
            newData[uppercaseKey] = data[key];
        } else {
            newData[key] = data[key];
        }
    }
    return newData;
}

/**
 *  打印出sql语句，便于查询问题，并且如果执行在主线程会给出提示
 *
 *  @param sql    sql语句
 *  @param values 值
 */
- (void)printSQLLog:(NSString *)sql values:(NSArray *)values {
    if ([NSThread isMainThread]) {
        NSLog(@"请注意该SQL语句在主线程执行：%@", [self buildPrintSql:sql values:values]);
    }
}

/**
 *  打印出sql语句，便于查询问题，并且如果执行在主线程会给出提示
 *
 *  @param sql    sql语句
 */
- (void)printSQLLog:(NSString *)sql {
    [self printSQLLog:sql values:nil];
}

/**
 *  构造日志sql语句，便于查看
 *
 *  @param sql    sql语句
 *  @param values 值，如果为nil则sql是非预编译语句
 *
 *  @return 返回合成之后的sql
 */
- (NSString *)buildPrintSql:(NSString *)sql values:(NSArray *)values {
    if (!values) {
        return sql;
    }
    NSMutableString *mutableSql = [[NSMutableString alloc] initWithString:sql];
    for (NSString *value in values) {
        NSRange range = [mutableSql rangeOfString:@"?"];
        [mutableSql replaceCharactersInRange:range withString:[NSString stringWithFormat:@"'%@'", value]];
    }
    return mutableSql;
}

#pragma mark - Getters and Setters

+ (dispatch_queue_t)workQueue {
    static dispatch_once_t onceToken;
    static dispatch_queue_t workQueue;
    dispatch_once(&onceToken, ^{
        workQueue = dispatch_queue_create("com.ichensheng.database.workqueue", DISPATCH_QUEUE_SERIAL);
    });
    return workQueue;
}

- (TCDatabase *)database {
    return [self.provider databaseWithName:self.databaseName];
}

- (FMDatabaseQueue *)dbQueue {
    return [[self database] dbQueue];
}

- (NSDictionary *)tablesDef {
    return [[self database] tablesDef];
}

- (void)setDynamicTable:(BOOL)dynamicTable {
    _dynamicTable = dynamicTable;
    if (![_table hasPrefix:kDynamicTablePrefix]) {
        _table = [NSString stringWithFormat:@"%@%@", kDynamicTablePrefix, _table];
    }
}

@end


/**
 *  查询条件Bean
 */
@implementation TCSqlBean

/**
 *  静态方法获取TCSqlBean对象
 *
 *  @return 创建新的TCSqlBean对象
 */
+ (instancetype)instance {
    return [[[self class] alloc] init];
}

- (instancetype)init {
    if (self = [super init]) {
        _dictionary = [NSMutableDictionary dictionary];
    }
    return self;
}

/**
 *  增加'='过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)andEQ:(NSString *)field value:(NSString *)value {
    [self andWhere:field op:@"=" value:value];
}

/**
 *  增加'<>'过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)andNE:(NSString *)field value:(NSString *)value {
    [self andWhere:field op:@"<>" value:value];
}

/**
 *  增加'>'过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)andGT:(NSString *)field value:(NSString *)value {
    [self andWhere:field op:@">" value:value];
}

/**
 *  增加'>='过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)andGTE:(NSString *)field value:(NSString *)value {
    [self andWhere:field op:@">=" value:value];
}

/**
 *  增加'<'过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)andLT:(NSString *)field value:(NSString *)value {
    [self andWhere:field op:@"<" value:value];
}

/**
 *  增加'<='过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)andLTE:(NSString *)field value:(NSString *)value {
    [self andWhere:field op:@"<=" value:value];
}

/**
 *  增加'like'过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)andLike:(NSString *)field value:(NSString *)value {
    [self andWhere:field op:@"like" value:value];
}

/**
 *  增加'not like'过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)andNotLike:(NSString *)field value:(NSString *)value {
    [self andWhere:field op:@"not like" value:value];
}

/**
 *  增加关系过滤项
 *
 *  @param field 字段
 *  @param op    sql操作符：=、like、<、>、<=、>=、<>等等
 *  @param value 值
 */
- (void)andWhere:(NSString *)field op:(NSString *)op value:(NSString *)value {
    if (field && op && value) { // 三个参数都不为nil时才拼接where条件
        [[self where] appendString:[NSString stringWithFormat:@" and %@ %@ ?", field, op]];
        [[self vars] addObject:value];
    } else {
        NSLog(@"andWhere:op:value出错：%@-%@-%@", field, op, value);
    }
}

/**
 *  增加'In'过滤项
 *
 *  @param field  字段
 *  @param values 值
 */
- (void)andIn:(NSString *)field values:(NSArray *)values {
    NSMutableArray *valueArray = [NSMutableArray array];
    for (NSString *value in values) {
        [valueArray addObject:value];
    }
    if (valueArray.count > 0) {
        [[self where] appendFormat:@" and %@ in (%@)", field, [self preIn:valueArray]];
    }
}

/**
 *  增加'Not In'过滤项
 *
 *  @param field  字段
 *  @param values 值
 */
- (void)andNotIn:(NSString *)field values:(NSArray *)values {
    NSMutableArray *valueArray = [NSMutableArray array];
    for (NSString *value in values) {
        [valueArray addObject:value];
    }
    if (valueArray.count > 0) {
        [[self where] appendFormat:@" and %@ not in (%@)", field, [self preIn:valueArray]];
    }
}

/**
 *  增加'null'过滤
 *
 *  @param field 字段
 */
- (void)andNull:(NSString *)field {
    [[self where] appendFormat:@" and %@ %@", field, @"is null"];
}

/**
 *  增加'not null'过滤
 *
 *  @param field 字段
 */
- (void)andNotNull:(NSString *)field {
    [[self where] appendFormat:@" and %@ %@", field, @"is not null"];
}

/**
 *  增加复杂语句的支持
 *
 *  @param subSql 例如：and (a=? and b=?)或者更加复杂的查询
 *  @param values 问号对应的值数组
 */
- (void)subSql:(NSString *)subSql values:(NSArray *)values {
    subSql = [subSql stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    [[self where] appendFormat:@" %@", subSql];
    [[self vars] addObjectsFromArray:values];
}

/**
 *  增加'='过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)orEQ:(NSString *)field value:(NSString *)value {
    [self orWhere:field op:@"=" value:value];
}

/**
 *  增加'<>'过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)orNE:(NSString *)field value:(NSString *)value {
    [self orWhere:field op:@"<>" value:value];
}

/**
 *  增加'>'过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)orGT:(NSString *)field value:(NSString *)value {
    [self orWhere:field op:@">" value:value];
}

/**
 *  增加'>='过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)orGTE:(NSString *)field value:(NSString *)value {
    [self orWhere:field op:@">=" value:value];
}

/**
 *  增加'<'过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)orLT:(NSString *)field value:(NSString *)value {
    [self orWhere:field op:@"<" value:value];
}

/**
 *  增加'<='过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)orLTE:(NSString *)field value:(NSString *)value {
    [self orWhere:field op:@"<=" value:value];
}

/**
 *  增加'like'过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)orLike:(NSString *)field value:(NSString *)value {
    [self orWhere:field op:@"like" value:value];
}

/**
 *  增加'not like'过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)orNotLike:(NSString *)field value:(NSString *)value {
    [self orWhere:field op:@"not like" value:value];
}

/**
 *  增加'or'关系过滤项
 *
 *  @param field 字段
 *  @param op    sql操作符：=、like、<、>、<=、>=、<>等等
 *  @param value 值
 */
- (void)orWhere:(NSString *)field op:(NSString *)op value:(NSString *)value {
    [[self where] appendString:[NSString stringWithFormat:@" or %@ %@ ?", field, op]];
    [[self vars] addObject:value];
}

/**
 *  增加'in'过滤项
 *
 *  @param field  字段
 *  @param values 值
 */
- (void)orIn:(NSString *)field values:(NSArray *)values {
    NSMutableArray *valueArray = [NSMutableArray array];
    for (NSString *value in values) {
        [valueArray addObject:value];
    }
    if (valueArray.count > 0) {
        [[self where] appendFormat:@" or %@ in (%@)", field, [self preIn:valueArray]];
    }
}

/**
 *  增加'not in'过滤项
 *
 *  @param field 字段
 *  @param value 值
 */
- (void)orNotIn:(NSString *)field values:(NSArray *)values {
    NSMutableArray *valueArray = [NSMutableArray array];
    for (NSString *value in values) {
        [valueArray addObject:value];
    }
    if (valueArray.count > 0) {
        [[self where] appendFormat:@" or %@ not in (%@)", field, [self preIn:valueArray]];
    }
}

/**
 *  增加'null'过滤
 *
 *  @param field 字段
 */
- (void)orNull:(NSString *)field {
    [[self where] appendFormat:@" or %@ %@", field, @" is null"];
}

/**
 *  增加'not null'过滤
 *
 *  @param field 字段
 */
- (void)orNotNull:(NSString *)field {
    [[self where] appendFormat:@" or %@ %@", field, @" is not null"];
}

/**
 *  分组条件
 *
 *  @param field 字段
 */
- (void)groupBy:(NSString *)field {
    [self.dictionary setObject:[NSString stringWithFormat:@" group by %@", field]
                        forKey:GROUP];
}

/**
 *  升序
 *
 *  @param field 字段
 */
- (void)asc:(NSString *)field {
    NSMutableString *order = [self order];
    if (order.length > 0) {
        [order appendFormat:@", %@ asc", field];
    } else {
        [order appendFormat:@" order by %@ asc", field];
    }
}

/**
 *  倒序
 *
 *  @param field 字段
 */
- (void)desc:(NSString *)field {
    NSMutableString *order = [self order];
    if (order.length > 0) {
        [order appendFormat:@", %@ desc", field];
    } else {
        [order appendFormat:@" order by %@ desc", field];
    }
}

/**
 *  指定获取哪几条数据
 *
 *  @param count  获取条数
 *  @param offset 偏移量
 */
- (void)limit:(NSUInteger)count offset:(NSUInteger)offset {
    NSString *limitOffset = [NSString stringWithFormat:@" limit %ld offset %ld", (long)count, (long)offset];
    [self.dictionary setObject:limitOffset forKey:LIMIT_OFFSET];
}

/**
 *  指定获取哪几条数据，默认便宜量为0
 *
 *  @param count  获取条数
 */
- (void)limit:(NSUInteger)count {
    [self limit:count offset:0];
}

/**
 *  设置分页参数
 *
 *  @param pageNum 页码
 *  @param showNum 每页条数
 */
- (void)pageNum:(NSUInteger)pageNum showNum:(NSUInteger)showNum {
    [self limit:showNum offset:(pageNum - 1) * showNum];
}

/**
 *  设置查询字段，逗号分隔
 *
 *  @param selects 查询字段
 */
- (void)selects:(NSString *)selects {
    [self.dictionary setObject:selects forKey:SELECTS];
}

/**
 *  获取where条件
 *
 *  @return where字符串
 */
- (NSMutableString *)where {
    NSMutableString *where = [self.dictionary objectForKey:WHERE];
    if (!where) {
        where = [NSMutableString string];
        [self.dictionary setObject:where forKey:WHERE];
    }
    return where;
}

/**
 *  获取排序
 *
 *  @return 排序字符串
 */
- (NSMutableString *)order {
    NSMutableString *order = [self.dictionary objectForKey:ORDER];
    if (!order) {
        order = [NSMutableString string];
        [self.dictionary setObject:order forKey:ORDER];
    }
    return order;
}

/**
 *  获取预编译值
 *
 *  @return 预编译值数组
 */
- (NSMutableArray *)vars {
    NSMutableArray *vars = [self.dictionary objectForKey:PRE_VALUES];
    if (!vars) {
        vars = [NSMutableArray array];
        [self.dictionary setObject:vars forKey:PRE_VALUES];
    }
    return vars;
}

/**
 *  构造'In'条件
 *
 *  @param values In的值
 *
 *  @return In语句
 */
- (NSString *)preIn:(NSArray *)values {
    NSMutableString *mutableString = [NSMutableString string];
    NSMutableArray *vars = [self vars];
    NSInteger size = values.count;
    for (NSInteger i = 0; i < size; i++) {
        [mutableString appendString:@"?,"];
        [vars addObject:values[i]];
    }
    return [mutableString substringWithRange:NSMakeRange(0, mutableString.length - 1)];
}

@end
