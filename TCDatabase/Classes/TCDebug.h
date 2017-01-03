//
//  TCDebug.h
//  TCDatabase
//
//  Created by 陈 胜 on 2017/1/3.
//  Copyright © 2017年 陈胜. All rights reserved.
//

#ifndef TCDebug_h
#define TCDebug_h

#if (!defined(__OPTIMIZE__) && !defined (NSLog))
#define NSLog(...) printf("%f %s\n",[[NSDate date]timeIntervalSince1970],[[NSString stringWithFormat:__VA_ARGS__]UTF8String]);
#endif

#endif /* TCDebug_h */
