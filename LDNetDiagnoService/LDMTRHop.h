//
//  LDMTRHop.h
//  Pods
//
//  Created by zhao on 2017/9/6.
//
//

#import <Foundation/Foundation.h>

@interface LDMTRHop : NSObject

@property (nonatomic) int index;
@property (copy, nonatomic) NSString *hostAddr;

- (void)addRTT:(long)RTT; // -1 表示丢失
- (NSString *)report;

@end
