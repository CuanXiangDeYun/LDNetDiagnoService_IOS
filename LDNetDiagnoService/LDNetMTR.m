//
//  LDNetMTR.m
//  Pods
//
//  Created by zhao on 2017/9/6.
//
//

#import "LDNetMTR.h"
#include <sys/socket.h>
#include <netdb.h>
#import "LDNetMTRPathResolver.h"
#import "LDNetPing.h"

@interface LDNetMTR () <LDNetMTRPathResolverDelegate, LDNetPingDelegate>

@property (strong, nonatomic) LDNetMTRPathResolver *pathResolver;
@property (strong, nonatomic) LDNetPing *pinger;
@property (assign, nonatomic) NSInteger currentHostIndex;
@property (strong, nonatomic) NSArray *hops;

@end

@implementation LDNetMTR

- (void)mtrWithHost:(NSString *)host
{
    if (!host.length) {
        return;
    }
    self.currentHostIndex = 0;
    self.pathResolver = [LDNetMTRPathResolver new];
    self.pathResolver.delegate = self;
    self.isRunning = YES;
    [self start:host];
}

- (void)stopMTR {
    [self.pinger stopPing];
    [self.pathResolver stopResolve];
    self.isRunning = NO;
}

- (void)appendText:(NSString *)text {
    [self.delegate appendMTRLog:text];
}

- (void)start:(NSString *)host
{
    [self.delegate appendMTRLog:@"---------MTR Begin----------"];
    [self.delegate appendMTRLog:@"resolve path..."];
    [self.pathResolver resolveWithHost:host];
}

- (void)stop
{
    [self.delegate appendMTRLog:@"HOST:                      	Loss%	Snt	 Last	  Avg	 Best	 Wrst	StDev"];
    for (LDMTRHop *hop in self.hops) {
        NSString *log = [hop report];
        [self.delegate appendMTRLog:log];
    }
    self.isRunning = NO;
    [self.delegate appendMTRLog:@"---------MTR End-----------"];
    [self.delegate mtrDidEnd];
}

#pragma mark LDNetMTRPathResolverDelegate
- (void)didResolve:(NSMutableArray<LDMTRHop *> *)hops {
    self.hops = hops;
    [self.delegate appendMTRLog:@"ping..."];
    [self ping];
}

- (void)ping {
    if (!self.isRunning) {
        return;
    }
    if (self.currentHostIndex >= self.hops.count) {
        [self stop];
        return;
    }
    self.pinger = [[LDNetPing alloc] init];
    self.pinger.count = 10;
    self.pinger.delegate = self;
    LDMTRHop *hop = self.hops[self.currentHostIndex];
    if (hop.hostAddr) {
        [self.pinger runWithHop:hop];
        self.currentHostIndex++;
    } else {
        self.currentHostIndex++;
        [self ping];
    }
}

- (void)netPingDidEnd {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self ping];
    });
}

- (void)appendPingLog:(NSString *)log {

}

@end
