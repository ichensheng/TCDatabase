//
//  TCDatabaseManager.m
//  TCDatabase
//
//  Created by 陈 胜 on 16/6/13.
//  Copyright © 2016年 陈胜. All rights reserved.
//

#import "TCDatabaseManager.h"

@interface TCDatabaseManager()

@property (nonatomic, strong) NSMutableDictionary *databases;
@property (nonatomic, strong) NSMutableDictionary *userDAOCache;
@property (nonatomic, strong) NSMutableDictionary *systemDAOCache;

@end

@implementation TCDatabaseManager

+ (instancetype)sharedInstance {
    static TCDatabaseManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] initPrivate];
    });
    return sharedManager;
}

- (instancetype)init {
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

- (instancetype)initPrivate {
    return [super init];
}

/**
 *  打开数据库
 */
- (void)openDatabase {
    [self checkDelegate];
    NSLog(@"打开数据库");
    NSString *userDbFilePath = [self.delegate userDbFilePath];
    NSString *userTableBundleName = [self.delegate userTableBundleName];
    NSString *systemDbFilePath = [self.delegate systemDbFilePath];
    NSString *systemTableBundleName = [self.delegate systemTableBundleName];
    TCDatabase *userDatabase = [[TCDatabase alloc] initWithPath:userDbFilePath tableBundle:userTableBundleName];
    TCDatabase *systemDatabase = [[TCDatabase alloc] initWithPath:systemDbFilePath tableBundle:systemTableBundleName];
    self.databases[kUserDatabaseName] = userDatabase;
    self.databases[kSystemDatabaseName] = systemDatabase;
}

/**
 *  关闭数据库
 */
- (void)closeDatabase {
    NSLog(@"关闭数据库");
    self.databases = nil;
    self.userDAOCache = nil;
    self.systemDAOCache = nil;
}

/**
 *  获取用户数据库访问对象
 *
 *  @param table 表名
 *
 *  @return TCDatabaseDAO
 */
- (TCDatabaseDAO *)databaseDAO:(NSString *)table {
    NSString *uppercaseTable = [table uppercaseString];
    TCDatabaseDAO *databaseDAO = self.userDAOCache[uppercaseTable];
    if (!databaseDAO) {
        databaseDAO = [[TCDatabaseDAO alloc] initWithTable:table
                                              databaseName:kUserDatabaseName
                                                  provider:self];
        self.userDAOCache[uppercaseTable] = databaseDAO;
    }
    return databaseDAO;
}

/**
 *  获取系统数据库访问对象
 *
 *  @param table 表名
 *
 *  @return TCDatabaseDAO
 */
- (TCDatabaseDAO *)sysDatabaseDAO:(NSString *)table {
    NSString *uppercaseTable = [table uppercaseString];
    TCDatabaseDAO *databaseDAO = self.systemDAOCache[uppercaseTable];
    if (!databaseDAO) {
        databaseDAO = [[TCDatabaseDAO alloc] initWithTable:table
                                              databaseName:kSystemDatabaseName
                                                  provider:self];
        self.systemDAOCache[uppercaseTable] = databaseDAO;
    }
    return databaseDAO;
}

#pragma mark TCDatabaseProvider

- (TCDatabase *)databaseWithName:(NSString *)name {
    return self.databases[name];
}

#pragma mark - Private Methods

/**
 *  检查代理类和方法
 */
- (void)checkDelegate {
    NSAssert(self.delegate, @"TCDatabaseManager代理必须设置");
    if (![self.delegate respondsToSelector:@selector(userDbFilePath)]) {
        NSAssert(NO, @"TCDatabaseManagerDelegate代理方法userDbFilePath必须实现");
    }
    if (![self.delegate respondsToSelector:@selector(userTableBundleName)]) {
        NSAssert(NO, @"TCDatabaseManagerDelegate代理方法userTableBundleName必须实现");
    }
    if (![self.delegate respondsToSelector:@selector(systemDbFilePath)]) {
        NSAssert(NO, @"TCDatabaseManagerDelegate代理方法systemDbFilePath必须实现");
    }
    if (![self.delegate respondsToSelector:@selector(systemTableBundleName)]) {
        NSAssert(NO, @"TCDatabaseManagerDelegate代理方法systemTableBundleName必须实现");
    }
}

#pragma mark - Getters and Setters

- (NSMutableDictionary *)databases {
    if (!_databases) {
        _databases = [NSMutableDictionary dictionary];
    }
    return _databases;
}

- (NSMutableDictionary *)userDAOCache {
    if (!_userDAOCache) {
        _userDAOCache = [NSMutableDictionary dictionary];
    }
    return _userDAOCache;
}

- (NSMutableDictionary *)systemDAOCache {
    if (!_systemDAOCache) {
        _systemDAOCache = [NSMutableDictionary dictionary];
    }
    return _systemDAOCache;
}

@end
