//
//  LDNetMTRPathResolver.m
//  Pods
//
//  Created by zhao on 2017/9/6.
//
//

#import "LDNetMTRPathResolver.h"
#include <sys/socket.h>
#include <netdb.h>
#import "LDSimplePing.h"
#import "LDMTRHop.h"

#define TRACERT_PACKET_COUNT 2
@interface LDNetMTRPathResolver () <LDSimplePingDelegate>

@property (strong, nonatomic) NSMutableArray<LDMTRHop *> *hops;
@property NSDate *startDate;
@property (nonatomic) LDSimplePing *traceRoute;
@property NSTimer *sendTimer;
@property NSTimer *sendTimeoutTimer;
@property NSInteger sendSequence;
#define TRACERT_MAX_TTL 30
@property int currentTTL;               // ttl increase from number 1
@property NSInteger packetCountPerTTL;  // per RTT

@property (nonatomic, copy) NSString *ipAddress;
@property (copy, nonatomic) NSString *host;
@property (nonatomic, copy) NSString *icmpSrcAddress;

@end

@implementation LDNetMTRPathResolver

- (void)resolveWithHost:(NSString *)host
{
    if (!host.length) {
        return;
    }
    self.hops = [NSMutableArray arrayWithCapacity:TRACERT_MAX_TTL];
    self.host = host;
    [self start:host];
}

- (void)appendText:(NSString *)text {
}

- (void)stopResolve {
    [self invalidSendTimer];
    [self.sendTimeoutTimer invalidate];
    self.sendTimeoutTimer = nil;

    [self.traceRoute stop];
    self.traceRoute = nil;
}

- (void)start:(NSString *)host
{
    self.traceRoute = [[LDSimplePing alloc] initWithHostName:host];
    self.traceRoute.packetCountPerPing = TRACERT_PACKET_COUNT;
    self.traceRoute.delegate = self;
    [self.traceRoute start];
    do {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    } while (self.traceRoute != nil);
}

- (void)stop
{
    [self.delegate didResolve:self.hops];
    [self stopResolve];
}

- (void)sendPingWithTTL:(int)ttl
{
    self.packetCountPerTTL = 0;
    
    [self.traceRoute setTTL:ttl];
    [self.traceRoute sendPing];
    
    self.sendTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(checkSingleRoundTimeout) userInfo:nil repeats:NO];
    
}

- (void)invalidSendTimer
{
    [self.sendTimer invalidate];
    self.sendTimer = nil;
}

- (void)checkSingleRoundTimeout
{
    NSString *msg;
    switch (self.packetCountPerTTL) {
        case 0:
            msg = [NSString stringWithFormat:@"#%ld *  *  *\n", (long)self.sendSequence];
            [self appendHopWithSequence:self.sendSequence andHost:nil];
            break;
        case 1:
            msg = [NSString stringWithFormat:@"  *  *\n"];
            break;
        case 2:
            msg = [NSString stringWithFormat:@"  *\n"];
            break;
            
        default:
            break;
    }
    [self appendText:msg];
    
    [self sendPing];
}

- (BOOL)sendPing
{
    NSLog(@"sendPing ttl %d", self.currentTTL);
    self.currentTTL += 1;
    if (self.currentTTL > TRACERT_MAX_TTL) {
        NSString *msg = [NSString stringWithFormat:@"TTL exceed the Max, stop the test"];
        [self appendText:msg];
        [self stop];
        return NO;
    }
    
    [self sendPingWithTTL:self.currentTTL];
    return YES;
}

- (NSString *)displayAddressForAddress:(NSData *)address
{
    
#define	NI_MAXHOST	1025
#define	NI_NUMERICHOST	0x00000002
    int         err;
    NSString *  result;
    char        hostStr[NI_MAXHOST];
    
    result = nil;
    
    if (address != nil) {
        err = getnameinfo(address.bytes, (socklen_t) address.length, hostStr, sizeof(hostStr), NULL, 0, NI_NUMERICHOST);
        if (err == 0) {
            result = @(hostStr);
        }
    }
    
    if (result == nil) {
        result = @"?";
    }
    
    return result;
}

#pragma mark - SimplePingDelegate
- (void)simplePing:(LDSimplePing *)pinger didStartWithAddress:(NSData *)address
{
    NSLog(@"%s", __func__);
    self.ipAddress = [self displayAddressForAddress:address];
    NSLog(@"%@", self.ipAddress);
    NSString *msg = [NSString stringWithFormat:@"Tracert %@ (%@)\n", self.host, self.ipAddress];
    [self appendText:msg];
    
    self.currentTTL = 1; // init ttl
    [self sendPingWithTTL:self.currentTTL];
    
}

- (void)simplePing:(LDSimplePing *)pinger didFailWithError:(NSError *)error
{
    NSLog(@"%s", __func__);
    NSLog(@"%@\n%@\n%@", error, error.domain, error.userInfo);
    
    NSString *msg = [NSString stringWithFormat:@"Failed to resolve %@", self.host];
    [self appendText:msg];
    [self stop];
}

- (void)simplePing:(LDSimplePing *)pinger didSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber
{
    NSLog(@"%s", __func__);
    NSLog(@"#%u sent", sequenceNumber);
    self.sendSequence = sequenceNumber;
    self.startDate = [NSDate date];
}

- (void)simplePing:(LDSimplePing *)pinger didFailToSendPacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber error:(NSError *)error
{
    NSLog(@"%s", __func__);
    NSLog(@"%@ %d %@", packet, sequenceNumber, error);
}

- (void)simplePing:(LDSimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet sequenceNumber:(uint16_t)sequenceNumber
{
    NSLog(@"%s", __func__);
    [self invalidSendTimer];
    
    NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:self.startDate];
    NSLog(@"Host responsed in %0.2lf ms", interval*1000);
    NSLog(@"#%u received, size=%zu", sequenceNumber, (unsigned long)packet.length);
    [self.sendTimeoutTimer invalidate];
    if (sequenceNumber != self.sendSequence) {
        return;
    }
    NSString *msg = [NSString stringWithFormat:@"#%u reach the destination %@, test completed", sequenceNumber, self.ipAddress];
    [self appendHopWithSequence:sequenceNumber andHost:self.ipAddress];
    [self appendText:msg];
    
    [self stop];
}

- (void)simplePing:(LDSimplePing *)pinger didReceiveUnexpectedPacket:(NSData *)packet
{
    NSLog(@"%s", __func__);
    NSString *msg;
    
    NSTimeInterval interval = [[NSDate date] timeIntervalSinceDate:self.startDate];
    NSLog(@"Host responsed in %0.2lf ms", interval*1000);
    
    NSString *srcAddr = [self.traceRoute srcAddrInIPv4Packet:packet];
    [self appendHopWithSequence:self.sendSequence andHost:srcAddr];
    if (0 == self.packetCountPerTTL) {
        self.icmpSrcAddress = srcAddr;
        self.packetCountPerTTL += 1;
        msg = [NSString stringWithFormat:@"#%ld %@   %0.2lfms", (long)self.sendSequence, self.icmpSrcAddress, interval*1000];
    } else {
        self.packetCountPerTTL += 1;
        msg = [NSString stringWithFormat:@" %0.2lfms", interval*1000];
    }
    
    [self appendText:msg];
    
    if (TRACERT_PACKET_COUNT == self.packetCountPerTTL) {
        [self invalidSendTimer];
        [self appendText:@"\n"];
        
        [self sendPing];
    }
}

- (void)appendHopWithSequence:(NSInteger)sequence andHost:(NSString *)host {
    if (sequence + 1 > self.hops.count) {
        LDMTRHop *hop = [LDMTRHop new];
        hop.index = (int)self.sendSequence + 1;
        hop.hostAddr = host;
        [self.hops addObject:hop];
    }
}

@end
