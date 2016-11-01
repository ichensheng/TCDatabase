//
//  TCDatabaseProvider.h
//  TCDatabase
//
//  Created by 陈 胜 on 16/11/1.
//  Copyright © 2016年 陈胜. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TCDatabase;
@protocol TCDatabaseProvider <NSObject>

- (TCDatabase *)databaseWithName:(NSString *)name;

@end
