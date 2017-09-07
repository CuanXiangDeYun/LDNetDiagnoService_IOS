//
//  LDNetMTR.h
//  Pods
//
//  Created by zhao on 2017/9/6.
//
//

#import <Foundation/Foundation.h>

@protocol LDNetMTRDelegate <NSObject>
@required
- (void)appendMTRLog:(NSString *)mtrLog;
- (void)mtrDidEnd;
@end

@interface LDNetMTR : NSObject

@property (weak, nonatomic) id<LDNetMTRDelegate> delegate;
@property (nonatomic) BOOL isRunning;

- (void)mtrWithHost:(NSString *)host;
- (void)stopMTR;

@end
