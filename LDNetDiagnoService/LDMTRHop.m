//
//  LDMTRHop.m
//  Pods
//
//  Created by zhao on 2017/9/6.
//
//

#import "LDMTRHop.h"

@interface LDMTRHop ()
@property (strong, nonatomic) NSMutableArray *RTTs;
@end

@implementation LDMTRHop

- (instancetype)init {
    self = [super init];
    if (self) {
        self.RTTs = [NSMutableArray array];
    }
    return self;
}

- (void)addRTT:(long)RTT {
    [self.RTTs addObject:@(RTT)];
}

- (NSString *)report {
    NSInteger loss = 0;
    long last = 0, avg = 0, best = LONG_MAX, wrst = LONG_MIN, sum = 0, stDev = 0;
    float lossRate = 0;
    if (self.RTTs.count > 0) {
        for (NSNumber *rtt in self.RTTs) {
            long value = [rtt longValue];
            if (value == -1) {
                loss ++;
            } else {
                if (value < best) {
                    best = value;
                }
                if (value > wrst) {
                    wrst = value;
                }
                sum += value;
            }
        }
        if (self.RTTs.count == loss) {
            lossRate = 1;
            best = 0;
            wrst = 0;
        } else {
            avg = sum / (self.RTTs.count - loss);
            lossRate = loss / self.RTTs.count;
            last = ((NSNumber *)self.RTTs.lastObject).longValue;
            for (NSNumber *rtt in self.RTTs) {
                long value = [rtt longValue];
                if (value == -1) {
                    loss ++;
                } else {
                    stDev += (avg - value) * (avg - value);
                }
            }
        }
    } else {
        lossRate = 1;
        best = 0;
        wrst = 0;
    }
    
    NSMutableString *output = [NSMutableString string];
    [output appendFormat:@"%2d.|-- %-20s\t%5.1f\t%3d\t%5.1f\t%5.1f\t%5.1f\t%5.1f\t%5.1f", self.index, [self.hostAddr ?: @"???" UTF8String], lossRate * 100, (int)self.RTTs.count, (float)last / 1000, (float)avg / 1000, (float)best / 1000, (float)wrst / 1000, (float)stDev / (1000 * 1000)];
    return [output copy];
}

@end
