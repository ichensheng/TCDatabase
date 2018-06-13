//
//  TCDatabase.m
//  TCDatabase
//
//  Created by 陈 胜 on 16/5/23.
//  Copyright © 2016年 陈胜. All rights reserved.
//

#import "TCDatabase.h"
#import <FMDB/FMTokenizers.h>
#import "TCSimpleTokenizer.h"
#import <FCFileManager/FCFileManager.h>
#import <sqlite3.h>

static NSString * const kLastReleaseSpaceTimeKey = @"lastReleaseSpaceTimeKey";  // 上一次清理SQLite的时间
static NSString * const kTimeFormat = @"yyyy-MM-dd HH:mm:ss:SSS";               // 时间戳格式
static const NSInteger kReleaseSpaceAge = 7 * 24 * 60 * 60;                     // 清理SQLite存储空间周期，1周

static NSString * const kTokenizerModuleName = @"fmdb";
static NSString * const kTokenizerName = @"simple";
static FMStopWordTokenizer *stopTok;

@interface TCDatabase()

@property (nonatomic, strong, readwrite) FMDatabaseQueue *dbQueue;
@property (nonatomic, strong, readwrite) NSMutableDictionary *tablesDef;

@end

@implementation TCDatabase

/**
 *  构造数据库对象，包含数据库访问队列、表定义、数据库加密key
 *
 *  @param path          数据文件路径
 *  @param tableBundle   表定义bundle
 *
 *  @return 数据库对象
 */
- (instancetype)initWithPath:(NSString *)path
                 tableBundle:(NSString *)tableBundle {
    
    if (self = [super init]) {
        [self loadTableDefinition:tableBundle]; // 加载表定义
        [self createDBQueueWithPath:path];      // 创建数据库访问对象
        [self updateDatabase];                  // 更新数据库
        [self releaseSpace];                    // 清理数据库存储空间
    }
    return self;
}

/**
 *  关闭数据库
 */
- (void)close {
    if (_dbQueue) {
        [_dbQueue close];
        _dbQueue = nil;
        _tablesDef = nil;
    }
}

/**
 *  自动检测扩展动态表
 *
 *  @param table 表名，会自动添加前缀
 *  @param data  动态表数据
 *  @param db    FMDatabase，防止嵌套
 */
- (void)checkDynamicTable:(NSString *)table
                     data:(NSDictionary *)data
                   withDb:(FMDatabase *)db {
    
    table = [table uppercaseString];
    NSMutableDictionary *tableDef = nil;
    NSString *keyName = kDynamicKey;
    if (self.tablesDef[table]) {
        tableDef = self.tablesDef[table];
    } else {
        if ([self existsTables:@[table] withDb:db]) {
            NSMutableDictionary *tmpTableDef = [NSMutableDictionary dictionary];
            NSArray *columnsOfTable = [self columnsOfTable:table withDb:db];
            if (columnsOfTable.count > 0) {
                NSMutableArray *cols = [NSMutableArray array];
                NSMutableArray *columnNames = [NSMutableArray array];
                for (NSString *column in columnsOfTable) {
                    [cols addObject:@{@"name":[column uppercaseString], @"type": @"text"}];
                    [columnNames addObject:[column uppercaseString]];
                }
                tmpTableDef[@"table"] = table;
                tmpTableDef[@"key"] = keyName;
                tmpTableDef[@"cols"] = cols;
                tmpTableDef[@"columnNames"] = columnNames;
                self.tablesDef[table] = tableDef = tmpTableDef;
            }
        }
    }
    
    if (!data) {
        return;
    }
    
    if (tableDef) {
        NSMutableArray *cols = tableDef[@"cols"];
        NSMutableArray *columnNames = tableDef[@"columnNames"];
        for (NSString *key in data) {
            BOOL exists = NO;
            for (NSString *column in columnNames) {
                if ([column isEqualToString:[key uppercaseString]]) {
                    exists = YES;
                    break;
                }
            }
            if (!exists) {
                [cols addObject:@{@"name":[key uppercaseString], @"type": @"text"}];
                [columnNames addObject:[key uppercaseString]];
            }
        }
    } else {
        tableDef = [NSMutableDictionary dictionary];
        NSMutableArray *cols = [NSMutableArray array];
        [cols addObject:@{@"name":keyName, @"type": @"text"}];
        NSMutableArray *columnNames = [NSMutableArray array];
        [columnNames addObject:keyName];
        for (NSString *key in data) {
            [cols addObject:@{@"name":[key uppercaseString], @"type": @"text"}];
            [columnNames addObject:[key uppercaseString]];
        }
        
        tableDef[@"table"] = table;
        tableDef[@"key"] = keyName;
        tableDef[@"cols"] = cols;
        tableDef[@"columnNames"] = columnNames;
        self.tablesDef[table] = tableDef;
    }
    
    if ([self existsTables:@[table] withDb:db]) {
        [self addColumnsFromTableDef:tableDef withDb:db];
    } else {
        [self createTableWithDef:tableDef withDb:db];
    }
}

#pragma mark - Private Methods

/**
 *  创建用户数据库连接队列
 */
- (void)createDBQueueWithPath:(NSString *)dbPath {
    if (dbPath) {
        if (![FCFileManager existsItemAtPath:dbPath]) {
            [FCFileManager createDirectoriesForFileAtPath:dbPath];
        }
        [self makeProtectionNoneForFile:dbPath];
        int flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FILEPROTECTION_NONE;
        _dbQueue = [FMDatabaseQueue databaseQueueWithPath:dbPath flags:flags];

        /**
         *  递归直到成功
         */
        if (_dbQueue) {
            [_dbQueue inDatabase:^(FMDatabase *db) {
                [db installTokenizerModuleWithName:kTokenizerModuleName];
#ifdef DEBUG
                db.traceExecution = YES;
                db.logsErrors = YES;
                db.crashOnErrors = YES;
#endif
            }];
            NSLog(@"创建数据库访问对象: %@", dbPath);
        } else {
            @autoreleasepool {
                [NSThread sleepForTimeInterval:0.5f];
            }
            [self createDBQueueWithPath:dbPath];
        }
    }
}

/**
 *  数据库更新，根据数据定义的JSON文件自动更新
 */
- (void)updateDatabase {
    NSLog(@"开始升级数据库...");
    [self.tablesDef enumerateKeysAndObjectsUsingBlock:^(NSString *table, NSDictionary *def, BOOL *stop) {
#if (TARGET_IPHONE_SIMULATOR)
        if ([self existsTables:@[table]]) {
            [self addColumnsFromTableDef:def];
        } else {
            [self createTableWithDef:def];
        }
#else
        if (def[@"fts"]) { // 支持全文检索，fts3/fts4
            if ([self existsFTSTable:table ftsType:def[@"fts"]]) {
                NSArray *addColumn = [self checkNeedAddColumnForFTSTable:def];
                if (addColumn.count > 0) { // 判断需不需要添加字段
                    [self modifyBetweenFTSAndCommonTable:def newAddColumn:addColumn];
                }
            } else {
                [self createVirtualTableWithDef:def];
            }
        } else {
            /**
             * 存在全文检索表则先备份数据，创建普通表，再把数据复制到该表中，再删除全文检索表
             */
            if ([self existsFTSTable:table ftsType:def[@"fts"]]) {
                [self modifyBetweenFTSAndCommonTable:def newAddColumn:nil];
            } else {
                if ([self existsTables:@[table]]) {
                    [self addColumnsFromTableDef:def];
                } else {
                    [self createTableWithDef:def];
                }
            }
        }
#endif
        // 创建字段索引
        if (def[@"indexs"]) {
            [self createColumnIndex:def[@"indexs"] onTable:def[@"table"]];
        }
    }];
    NSLog(@"完成数据库升级");
}

/**
 *  设置数据库文件的保护等级为NSFileProtectionNone，未受保护，随时可以访问
 *
 *  @param filePath 文件路径
 */
- (void)makeProtectionNoneForFile:(NSString *)filePath {
    NSDictionary *attributes =
    [NSDictionary dictionaryWithObject:NSFileProtectionNone forKey:NSFileProtectionKey];
    [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:filePath error:nil];
}

/**
 *  加载表定义到内存里
 */
- (void)loadTableDefinition:(NSString *)tableBundle {
    NSLog(@"加载表定义...");
    [[self readTableDef:tableBundle] enumerateObjectsUsingBlock:^(NSDictionary *tableDef, NSUInteger idx, BOOL *stop) {
        NSMutableDictionary *mutableDef = [NSMutableDictionary dictionaryWithDictionary:tableDef];
        NSString *tableName = [mutableDef objectForKey:@"table"];
        [self.tablesDef setObject:mutableDef forKey:[tableName uppercaseString]];
        NSMutableArray *columnNameArray = [NSMutableArray array];
        for (NSDictionary *column in tableDef[@"cols"]) {
            [columnNameArray addObject:[column[@"name"] uppercaseString]];
        }
        [mutableDef setObject:columnNameArray forKey:@"columnNames"];
    }];
    
    /**
     * 构造分词器
     */
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        TCSimpleTokenizer *simpleTok = [[TCSimpleTokenizer alloc] initWithLocale:NULL];
        NSString *stopWordsPath = [[NSBundle mainBundle] pathForResource:@"stopWords.txt" ofType:nil];
        NSURL *stopWordsURL = [NSURL fileURLWithPath:stopWordsPath];
        stopTok = [FMStopWordTokenizer tokenizerWithFileURL:stopWordsURL baseTokenizer:simpleTok error:nil];
        [FMDatabase registerTokenizer:stopTok withKey:kTokenizerName];
    });
}

/**
 *  加载数据库表定义
 *
 *  @return 读取表定义
 */
- (NSArray *)readTableDef:(NSString *)bundleName {
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:bundleName ofType:@"bundle"];
    NSBundle *tableBundle = [NSBundle bundleWithPath:bundlePath];
    NSArray *tableFiles = [tableBundle pathsForResourcesOfType:@"json" inDirectory:nil];
    __block NSMutableArray *tableDefArray = [NSMutableArray array];
    [tableFiles enumerateObjectsUsingBlock:^(NSString *path, NSUInteger idx, BOOL *stop) {
        NSData *jsonData = [[NSData alloc] initWithContentsOfFile:path];
        NSDictionary *tableDef = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                 options:NSJSONReadingMutableContainers
                                                                   error:nil];
        if (tableDef) {
            [tableDefArray addObject:[self modifyTableDef:tableDef]];
        } else {
            NSString *errorInfo = [NSString stringWithFormat:@"表'%@'定义信息加载失败", [path lastPathComponent]];
            @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                           reason:errorInfo
                                         userInfo:nil];
        }
    }];
    return tableDefArray;
}

/**
 *  创建全文检索虚拟表
 *
 *  @param tableDef 表定义
 */
- (void)createVirtualTableWithDef:(NSDictionary *)tableDef {
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        NSString *tableName = tableDef[@"table"];
        BOOL renameSuccess = YES;
        NSString *backupTableName = [self backupTableName:tableName];
        BOOL existsOldTable = [self existsTables:@[tableName] withDb:db];
        if (existsOldTable) { // 原表存在则重命名该表
            NSString *renameSql = [NSString stringWithFormat:@"alter table %@ rename to %@", tableName, backupTableName];
            renameSuccess = [db executeUpdate:renameSql];
        }
        
        /**
         *  重命名成功之后创建全文检索表，然后把备份表数据复制到全文检索表里
         */
        if (renameSuccess) {
            [db executeUpdate:[self createVirtualTableSql:tableDef]];
            if (existsOldTable) { // 把原表里的数据复制到全文检索表里
                NSString *insertIntoSql = [self recoveryDataSqlFromBackupTable:tableDef newAddColumn:nil];
                [db executeUpdate:insertIntoSql];
                [db executeUpdate:[NSString stringWithFormat:@"drop table %@", backupTableName]];
            }
        }
    }];
}

/**
 *  表存在则添加字段
 *
 *  @param tableDef 表定义
 *  @param db       FMDatabase，防止嵌套
 */
- (BOOL)addColumnsFromTableDef:(NSDictionary *)tableDef withDb:(FMDatabase *)db {
    NSString *tableName = [tableDef objectForKey:@"table"];
    NSArray *columnsOfTableInDatabase = [self columnsOfTable:tableName withDb:db];
    NSMutableArray *alterAddColumns = [NSMutableArray array];
    NSArray *columnsInTableDef = [tableDef objectForKey:@"cols"];
    for (NSInteger i = 0; i < columnsInTableDef.count; i++) {
        NSDictionary *columnDef = [columnsInTableDef objectAtIndex:i];
        NSString *columnName = [columnDef objectForKey:@"name"];
        NSString *columnType = [columnDef objectForKey:@"type"];
        NSString *isNotNull = [columnDef objectForKey:@"isNotNull"];
        Boolean isUnique = [[columnDef objectForKey:@"isUnique"] boolValue];
        NSString *checkValue = [columnDef objectForKey:@"checkValue"];
        NSString *defaultValue = [columnDef objectForKey:@"defaultValue"];
        
        // 数据里里不存在的字段需要添加
        if ([columnsOfTableInDatabase containsObject:columnName.lowercaseString] == NO) {
            NSMutableString *addColumePars = [NSMutableString stringWithFormat:@"%@ %@", columnName, columnType];
            if (isNotNull) {
                [addColumePars appendFormat:@" NOT NULL"];
            }
            
            if (isUnique) {
                [addColumePars appendFormat:@" UNIQUE"];
            }
            
            if (checkValue) {
                [addColumePars appendFormat:@" CHECK(%@)", checkValue];
            }
            
            if (defaultValue) {
                [addColumePars appendFormat:@" DEFAULT %@", defaultValue];
            }
            
            NSString *alertSQL = [NSString stringWithFormat:@"alter table %@ add column %@", tableName, addColumePars];
            NSString *initValue = [[columnType uppercaseString] isEqualToString:@"INTEGER"] ? @"0":@"''";
            NSString *initColumnValue = [NSString stringWithFormat:@"update %@ set %@=%@", tableName, columnName, initValue];
            BOOL success = [db executeUpdate:alertSQL];
            if (success) {
                [db executeUpdate:initColumnValue];
                [alterAddColumns addObject:columnName];
            }
        }
    }
    
    if (alterAddColumns.count > 0) {
        NSLog(@"表:%@添加字段:%@成功", tableName, alterAddColumns);
        return YES;
    } else {
        return NO;
    }
}

/**
 *  表存在则添加字段
 *
 *  @param tableDef 表定义
 */
- (BOOL)addColumnsFromTableDef:(NSDictionary *)tableDef {
    __block BOOL result = NO;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        result = [self addColumnsFromTableDef:tableDef withDb:db];
    }];
    return result;
}

/**
 *  判断存不存在全文检索表
 */
- (BOOL)existsFTSTable:(NSString *)table ftsType:(NSString *)ftsType {
    NSMutableArray *tableNames = [@[] mutableCopy];
    [tableNames addObject:table];
    [tableNames addObject:[NSString stringWithFormat:@"%@_content", table]];
    [tableNames addObject:[NSString stringWithFormat:@"%@_segdir", table]];
    [tableNames addObject:[NSString stringWithFormat:@"%@_segments", table]];
    if ([[ftsType lowercaseString] isEqualToString:@"fts4"]) {
        [tableNames addObject:[NSString stringWithFormat:@"%@_docsize", table]];
        [tableNames addObject:[NSString stringWithFormat:@"%@_stat", table]];
    }
    return [self existsTables:tableNames];
}

/**
 *  根据表名判断该表在数据库里存不存在
 *
 *  @param tableNames 表名
 *
 *  @return BOOL
 */
- (BOOL)existsTables:(NSArray *)tableNames {
    __block BOOL ifExists = NO;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        ifExists = [self existsTables:tableNames withDb:db];
    }];
    return ifExists;
}

/**
 *  根据表名判断该表在数据库里存不存在
 *
 *  @param tableName 表名
 *
 *  @return BOOL
 */
- (BOOL)existsTable:(NSString *)tableName {
    return [self existsTables:@[tableName]];
}

/**
 *  根据表名判断该表在数据库里存不存在
 *
 *  @param tableNames 表名
 *  @param db         FMDatabase
 *
 *  @return BOOL
 */
- (BOOL)existsTables:(NSArray *)tableNames withDb:(FMDatabase *)db {
    NSMutableString *sql = [[NSMutableString alloc] init];
    [sql appendString:@"select count(*) as 'count' from sqlite_master where type ='table' and upper(name) in ("];
    NSInteger tableNameCount = tableNames.count;
    for (NSInteger i = 0; i < tableNameCount; i++) {
        if (i == tableNameCount - 1) {
            [sql appendFormat:@"'%@')", [tableNames[i] uppercaseString]];
        } else {
            [sql appendFormat:@"'%@', ", [tableNames[i] uppercaseString]];
        }
    }
    FMResultSet *rs = [db executeQuery:sql withArgumentsInArray:tableNames];
    BOOL ifExists = NO;
    while ([rs next]) {
        NSInteger count = [rs intForColumn:@"count"];
        if (count == tableNameCount) {
            ifExists = YES;
        }
    }
    return ifExists;
}

/**
 *  判断全文检索表需不需要增加字段
 *
 *  @param tableDef 表定义
 *
 *  @return 检测结果
 */
- (NSArray *)checkNeedAddColumnForFTSTable:(NSDictionary *)tableDef {
    NSString *tableName = [tableDef objectForKey:@"table"];
    __block NSArray *columnsOfTableInDatabase = nil;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        columnsOfTableInDatabase = [self columnsOfTable:tableName withDb:db];
    }];
    NSMutableArray *addColumn = [[NSMutableArray alloc] init];
    NSArray *columnsInTableDef = [tableDef objectForKey:@"cols"];
    for (NSInteger i = 0; i < columnsInTableDef.count; i++) {
        NSDictionary *columnDefinition = [columnsInTableDef objectAtIndex:i];
        NSString *columnName = [columnDefinition objectForKey:@"name"];
        if ([columnsOfTableInDatabase containsObject:columnName.lowercaseString] == NO) {
            [addColumn addObject:[columnName uppercaseString]];
        }
    }
    return addColumn;
}

/**
 *  从数据库里加载表字段定义
 *
 *  @param tableName 表名
 *
 *  @return 数据库里的表字段
 */
- (NSArray *)columnsOfTable:(NSString *)tableName {
    __block NSArray *columnArray = [NSArray array];
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        columnArray = [self columnsOfTable:tableName withDb:db];
    }];
    return columnArray;
}

/**
 *  从数据库里加载表字段定义
 *
 *  @param tableName 表名
 *  @param db        FMDatabase
 *
 *  @return 数据库里的表字段
 */
- (NSArray *)columnsOfTable:(NSString *)tableName withDb:(FMDatabase *)db {
    NSString *select = [NSString stringWithFormat:@"select * from %@ limit 0", tableName];
    FMResultSet *rs = [db executeQuery:select];
    NSArray *columnArray = rs.columnNameToIndexMap.allKeys;
    [rs close];
    return columnArray;
}

/**
 *  把全文检索表改成普通表，或者重建全文检索表
 *
 *  @param tableDef  表定义
 *  @param addColumn 新添加字段
 */
- (void)modifyBetweenFTSAndCommonTable:(NSDictionary *)tableDef
                          newAddColumn:(NSArray *)addColumn {
    
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        NSString *tableName = tableDef[@"table"];
        NSString *backupTableName = [self backupTableName:tableName];
        NSString *renameSql = [NSString stringWithFormat:@"alter table %@ rename to %@", tableName, backupTableName];
        BOOL renameSuccess = [db executeUpdate:renameSql];
        if (renameSuccess) {
            /**
             * 创建正式表
             */
            if (addColumn.count > 0) {
                [db executeUpdate:[self createVirtualTableSql:tableDef]];
            } else {
                [self createTableWithDef:tableDef withDb:db];
            }
            
            /**
             * 数据从备份表复制到正式表里
             */
            NSString *copyDataSql = [self recoveryDataSqlFromBackupTable:tableDef newAddColumn:addColumn];
            [db executeUpdate:copyDataSql];
            
            /**
             *  删除备份表
             */
            [db executeUpdate:[NSString stringWithFormat:@"drop table %@", backupTableName]];
        }
    }];
}

/**
 *  备份表名
 *
 *  @param tableName 原表名
 *
 *  @return 备份表名
 */
- (NSString *)backupTableName:(NSString *)tableName {
    return [NSString stringWithFormat:@"%@_backup", tableName];
}

/**
 *  全文检索虚拟表创建语句
 *
 *  @param tableDef 表定义
 *
 *  @return 虚拟表创建语句
 */
- (NSString *)createVirtualTableSql:(NSDictionary *)tableDef {
    NSString *tableName = tableDef[@"table"];
    NSArray *cols = tableDef[@"cols"];
    NSMutableString *sql = [[NSMutableString alloc] init];
    [sql appendString:@"CREATE VIRTUAL TABLE "];
    [sql appendString:tableName];
    [sql appendString:[NSString stringWithFormat:@" USING %@ (", tableDef[@"fts"]]];
    NSInteger count = cols.count;
    for (NSInteger i = 0; i < count; i++) {
        NSString *name = cols[i][@"name"];
        [sql appendString:[NSString stringWithFormat:@"%@, ", name]];
    }
    [sql appendString:[NSString stringWithFormat:@"tokenize=%@ %@)", kTokenizerModuleName, kTokenizerName]];
    return sql;
}

/**
 *  表不存在则创建表
 *
 *  @param tableDef 表定义
 */
- (BOOL)createTableWithDef:(NSDictionary *)tableDef {
    __block BOOL executed = NO;
    [self.dbQueue inDatabase:^(FMDatabase *db) {
        executed = [self createTableWithDef:tableDef withDb:db];
    }];
    return executed;
}

/**
 *  表不存在则创建表
 *
 *  @param tableDef   表定义
 *  @param db         FMDatabase
 */
- (BOOL)createTableWithDef:(NSDictionary *)tableDef withDb:(FMDatabase *)db {
    NSString *tableName = [tableDef objectForKey:@"table"];
    NSString *pkStr = [tableDef objectForKey:@"key"];
    NSArray *columns = [tableDef objectForKey:@"cols"];
    if (columns.count == 0) {
        NSLog(@"表%@没有字段定义，不创建表", tableName);
        return NO;
    }
    NSMutableString *tablePars = [NSMutableString string];
    for (NSInteger i = 0; i < columns.count; i++) {
        if (i > 0) {
            [tablePars appendString:@","];
        }
        NSDictionary *columnDef = [columns objectAtIndex:i];
        NSString *columnName = [columnDef objectForKey:@"name"];
        NSString *columnType = [columnDef objectForKey:@"type"];
        NSString *isNotNull = [columnDef objectForKey:@"isNotNull"];
        NSString *isUnique = [columnDef objectForKey:@"isUnique"];
        NSString *checkValue = [columnDef objectForKey:@"checkValue"];
        NSString *defaultValue = [columnDef objectForKey:@"defaultValue"];
        [tablePars appendFormat:@"%@ %@", columnName, columnType];
        if (isNotNull) {
            [tablePars appendFormat:@" NOT NULL"];
        }
        
        if (isUnique) {
            [tablePars appendFormat:@" UNIQUE"];
        }
        
        if (checkValue) {
            [tablePars appendFormat:@" CHECK(%@)", checkValue];
        }
        
        if (defaultValue) {
            [tablePars appendFormat:@" DEFAULT %@", defaultValue];
        }
        
        if ([columnName isEqualToString:pkStr]) {
            [tablePars appendString:@" PRIMARY KEY NOT NULL"];
        }
    }
    NSString *createTableSQL = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@(%@)", tableName, tablePars];
    BOOL executed = [db executeStatements:createTableSQL];
    
    /**
     *  建立主键唯一索引
     */
    if (executed) {
        NSString *idxName = [NSString stringWithFormat:@"IDX_%@_PK", [tableName uppercaseString]];
        NSString *createIdxSQL = [NSString stringWithFormat:@"CREATE UNIQUE INDEX %@ ON %@(%@)", idxName, tableName, pkStr];
        [db executeUpdate:createIdxSQL];
    }
    return executed;
}

/**
 *  从备份表恢复数据
 *
 *  @param tableDefinition 表定义
 *  @param addColumn       新添加的字段
 *
 *  @return sql语句
 */
- (NSString *)recoveryDataSqlFromBackupTable:(NSDictionary *)tableDef newAddColumn:(NSArray *)addColumn {
    NSString *tableName = tableDef[@"table"];
    NSArray *cols = tableDef[@"cols"];
    NSMutableString *colString = [[NSMutableString alloc] init];
    NSInteger count = cols.count;
    for (NSInteger i = 0; i < count; i++) {
        NSString *name = cols[i][@"name"];
        if (![addColumn containsObject:name]) {
            if (i == count - 1) {
                [colString appendString:name];
            } else {
                [colString appendString:[NSString stringWithFormat:@"%@, ", name]];
            }
        }
    }
    if ([colString hasSuffix:@", "]) {
        [colString setString:[colString substringToIndex:colString.length - 2]];
    }
    NSMutableString *sql = [[NSMutableString alloc] init];
    NSString *backupTableName = [self backupTableName:tableName];
    [sql appendString:[NSString stringWithFormat:@"INSERT INTO %@ (", tableName]];
    [sql appendString:[NSString stringWithFormat:@"%@) SELECT %@ FROM %@", colString, colString, backupTableName]];
    return sql;
}

/**
 *  把表名、字段名、主键改成大写
 *
 *  @param tableDef 原始表定义
 *
 *  @return 返回修改之后的表定义
 */
- (NSDictionary *)modifyTableDef:(NSDictionary *)tableDef {
    NSMutableDictionary *newTableDef = [NSMutableDictionary dictionary];
    newTableDef[@"table"] = [tableDef[@"table"] uppercaseString];
    newTableDef[@"comment"] = tableDef[@"comment"];
    newTableDef[@"key"] = [tableDef[@"key"] uppercaseString];
    newTableDef[@"fts"] = [tableDef[@"fts"] uppercaseString];
    newTableDef[@"indexs"] = tableDef[@"indexs"];
    NSMutableArray *newColsDef = [NSMutableArray array];
    newTableDef[@"cols"] = newColsDef;
    for (NSDictionary *colDef in tableDef[@"cols"]) {
        NSMutableDictionary *newColDef = [NSMutableDictionary dictionaryWithDictionary:colDef];
        newColDef[@"name"] = [newColDef[@"name"] uppercaseString];
        [newColsDef addObject:newColDef];
    }
    return newTableDef;
}
        
- (BOOL)createColumnIndex:(NSArray *)indexs onTable:(NSString *)tableName {
    __block BOOL executed = YES;
    [indexs enumerateObjectsUsingBlock:^(NSDictionary *index, NSUInteger idx, BOOL *stop) {
        [self.dbQueue inDatabase:^(FMDatabase *db) {
            NSArray *columnNames = index[@"columns"];
            NSString *indexName = index[@"name"];
            NSString *existsIndexSql =
            [NSString stringWithFormat:@"SELECT count(1) as 'count' FROM sqlite_master WHERE type='index' and name='%@'", indexName];
            FMResultSet *rs = [db executeQuery:existsIndexSql];
            BOOL ifExists = NO;
            while ([rs next]) {
                NSInteger count = [rs intForColumn:@"count"];
                if (count > 0) {
                    ifExists = YES;
                }
            }
            if (!ifExists) {
                NSMutableString *createIndexSql =
                [[NSMutableString alloc] initWithFormat:@"CREATE INDEX %@ ON %@ (", indexName, tableName];
                [columnNames enumerateObjectsUsingBlock:^(NSString *columnName, NSUInteger idx, BOOL *stop) {
                    [createIndexSql appendFormat:@"%@,", columnName];
                }];
                [createIndexSql deleteCharactersInRange:NSMakeRange(createIndexSql.length - 1, 1)];
                [createIndexSql appendString:@")"];
                executed = [db executeUpdate:createIndexSql];
                if (!executed) {
                    *stop = YES;
                }
            }
        }];
    }];
    return executed;
}

/**
 *  执行命令VACUUM，释放SQLite存储空间
 */
- (void)releaseSpace {
    NSDate *expirationDate = [NSDate dateWithTimeIntervalSinceNow:-kReleaseSpaceAge];
    NSString *lastReleaseSpaceTime = [[NSUserDefaults standardUserDefaults] stringForKey:kLastReleaseSpaceTimeKey];
    if (lastReleaseSpaceTime) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:kTimeFormat];
        NSDate *lastReleaseSpaceDate = [formatter dateFromString:lastReleaseSpaceTime];
        if ([lastReleaseSpaceDate compare:expirationDate] == NSOrderedAscending) {
            NSLog(@"清理SQLite存储空间...");
            [self.dbQueue inDatabase:^(FMDatabase *db) {
                [db executeUpdate:@"VACUUM"];
            }];
            [self saveReleaseTime]; // 释放完毕保存本次释放时间
        }
    } else {
        // 保存一次释放时间，用于下次释放时比较
        [self saveReleaseTime];
    }
}

/**
 *  保存最初的时间戳，用于SQLite释放存储空间
 */
- (void)saveReleaseTime {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:kTimeFormat];
    [formatter setLocale:[NSLocale currentLocale]];
    NSString *currentTime = [formatter stringFromDate:[NSDate date]];
    [[NSUserDefaults standardUserDefaults] setObject:currentTime forKey:kLastReleaseSpaceTimeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Getters and Setters

- (NSMutableDictionary *)tablesDef {
    if (!_tablesDef) {
        _tablesDef = [NSMutableDictionary dictionary];
    }
    return _tablesDef;
}

@end
