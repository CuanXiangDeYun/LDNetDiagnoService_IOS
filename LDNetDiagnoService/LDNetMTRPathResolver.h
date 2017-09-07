//
//  LDNetMTRPathResolver.h
//  Pods
//
//  Created by zhao on 2017/9/6.
//
//

#import <Foundation/Foundation.h>
#import "LDMTRHop.h"

@protocol LDNetMTRPathResolverDelegate <NSObject>

@required
- (void)didResolve:(NSMutableArray<LDMTRHop *> *)hops;

@end

@interface LDNetMTRPathResolver : NSObject

@property (weak, nonatomic) id<LDNetMTRPathResolverDelegate> delegate;

- (void)resolveWithHost:(NSString *)host;
- (void)stopResolve;
@end
