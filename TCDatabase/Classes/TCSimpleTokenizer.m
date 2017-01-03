//
//  TCSimpleTokenizer.m
//  TCDatabase
//
//  Created by 陈 胜 on 16/5/23.
//  Copyright © 2016年 陈胜. All rights reserved.
//

#import "TCSimpleTokenizer.h"
#import <FMDB/FMDatabase+FTS3.h>
#import "TCDebug.h"

@implementation TCSimpleTokenizer

- (void)openTokenizerCursor:(FMTokenizerCursor *)cursor {
    cursor->tokenString = CFStringCreateMutable(NULL, 0);
    cursor->userObject = CFStringTokenizerCreate(NULL, cursor->inputString,
                                                 CFRangeMake(0, CFStringGetLength(cursor->inputString)),
                                                 kCFStringTokenizerUnitLineBreak, NULL);
}

- (BOOL)nextTokenForCursor:(FMTokenizerCursor *)cursor {
    CFStringTokenizerRef tokenizer = (CFStringTokenizerRef) cursor->userObject;
    CFMutableStringRef tokenString = (CFMutableStringRef) cursor->tokenString;
    
    CFStringTokenizerTokenType tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer);
    
    if (tokenType == kCFStringTokenizerTokenNone) {
        // No more tokens, we are finished.
        return YES;
    }
    
    // Found a regular word. The token is the lowercase version of the word.
    cursor->currentRange = CFStringTokenizerGetCurrentTokenRange(tokenizer);
    
    // The inline buffer approach is faster and uses less memory than CFStringCreateWithSubstring()
    CFStringInlineBuffer inlineBuf;
    CFStringInitInlineBuffer(cursor->inputString, &inlineBuf, cursor->currentRange);
    CFStringDelete(tokenString, CFRangeMake(0, CFStringGetLength(tokenString)));
    
    for (int i = 0; i < cursor->currentRange.length; ++i) {
        UniChar nextChar = CFStringGetCharacterFromInlineBuffer(&inlineBuf, i);
        CFStringTrimWhitespace(tokenString);
        CFStringAppendCharacters(tokenString, &nextChar, 1);
    }
    
    CFStringLowercase(tokenString, NULL);
    
    return NO;
}

@end
