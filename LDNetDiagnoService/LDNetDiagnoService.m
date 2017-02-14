//
//  LDNetDiagnoService.m
//  LDNetDiagnoServieDemo
//
//  Created by 庞辉 on 14-10-29.
//  Copyright (c) 2014年 庞辉. All rights reserved.
//
#import <UIKit/UIKit.h>
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import "LDNetDiagnoService.h"
#import "LDNetPing.h"
#import "LDNetTraceRoute.h"
#import "LDNetGetAddress.h"
#import "LDNetTimer.h"
#import "LDNetConnect.h"
#import <SDVersion.h>
#import "LDJailbreak.h"

@interface LDNetDiagnoService () <LDNetPingDelegate, LDNetTraceRouteDelegate> {
    NETWORK_TYPE _curNetType;
    NSString *_localIp;
    NSString *_gatewayIp;
    NSArray *_dnsServers;
    NSArray *_hostAddress;

    NSMutableString *_logInfo;  //记录网络诊断log日志
    BOOL _isRunning;
    LDNetPing *_netPinger;
    LDNetTraceRoute *_traceRouter;
    
    NSInteger _diagnosisDomainIndex;
}

@end

@implementation LDNetDiagnoService
#pragma mark - public method
/**
 * 初始化网络诊断服务
 */
- (instancetype)init {
    self = [super init];
    if (self) {
        _logInfo = [NSMutableString string];
        _isRunning = NO;
        _diagnosisDomainIndex = 0;
    }
    return self;
}

/**
 * 开始诊断网络
 */
- (void)startNetDiagnosis
{
    if (_domains.count == 0) return;
    
    if ([self.delegate respondsToSelector:@selector(netDiagnosisDidStarted)]) {
        [self.delegate netDiagnosisDidStarted];
    }

    _isRunning = YES;
    [_logInfo setString:@""];
    [self recordStepInfo:@"开始诊断\n"];
    [self recordCurrentTime];
    [self recordUser];
    [self recordCurrentAppVersion];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self recordLocalNetEnvironment]; //检测外网时用了一个同步请求
        
        //未联网不进行任何检测
        if (_curNetType == 0) {
            _isRunning = NO;
            [self recordStepInfo:@"\n当前主机未联网，请检查网络！"];
            [self recordStepInfo:@"\n网络诊断结束\n"];
            if ([self.delegate respondsToSelector:@selector(netDiagnosisDidEnd:)]) {
                [self.delegate netDiagnosisDidEnd:_logInfo];
            }
            return;
        }
        
        [self dialogsisEachDomain];
    });
}

/**
 * 停止诊断网络, 清空诊断状态
 */
- (void)stopNetDialogsis
{
    _diagnosisDomainIndex = 0;
    if (_isRunning) {
        _isRunning = NO;

        if (_netPinger) {
            [_netPinger stopPing];
        }

        if (_traceRouter) {
            [_traceRouter stopTrace];
        }
    }
    [self recordStepInfo:@"\n诊断结束"];
    if ([self.delegate respondsToSelector:@selector(netDiagnosisDidEnd:)]) {
        [self.delegate netDiagnosisDidEnd:_logInfo];
    }
}


/**
 * 打印整体loginInfo；
 */
- (void)printLogInfo
{
    NSLog(@"\n%@\n", _logInfo);
}


#pragma mark -
#pragma mark - private method
/**
 *  获取当前时间
 */
- (void)recordCurrentTime {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy.MM.dd HH:mm:ss"];
    NSString *dateString = [dateFormatter stringFromDate:[NSDate date]];
    
    [self recordStepInfo:[NSString stringWithFormat:@"时间：%@", dateString]];
}

/**
 *  记录用户id
 */
- (void)recordUser {
    if (_userId) {
        [self recordStepInfo:[NSString stringWithFormat:@"用户id: %@", _userId]];
    }
}

/*!
 *  @brief  获取App相关信息
 */
- (void)recordCurrentAppVersion
{
    //输出应用和设备信息
    NSDictionary *dicBundle = [[NSBundle mainBundle] infoDictionary];

    [self recordStepInfo:[NSString stringWithFormat:@"应用名称: %@", dicBundle[@"CFBundleDisplayName"]]];
    [self recordStepInfo:[NSString stringWithFormat:@"应用版本: %@", dicBundle[@"CFBundleShortVersionString"]]];
    [self recordStepInfo:[NSString stringWithFormat:@"Build: %@", dicBundle[@"CFBundleVersion"]]];

    //输出机器信息
    UIDevice *device = [UIDevice currentDevice];
    [self recordStepInfo:[NSString stringWithFormat:@"设备型号: %@", DeviceVersionNames[[SDVersion deviceVersion]]]];
    [self recordStepInfo:[NSString stringWithFormat:@"系统版本: %@", [device systemVersion]]];
    [self recordStepInfo:[NSString stringWithFormat:@"UUID: %@", [[[UIDevice currentDevice] identifierForVendor] UUIDString]]];
    [self recordStepInfo:[NSString stringWithFormat:@"是否越狱: %@", [LDJailbreak isJailbroken] ? @"YES" : @"NO"]];

    //运营商信息
    CTTelephonyNetworkInfo *netInfo = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier = [netInfo subscriberCellularProvider];
    if (carrier != NULL) {
        [self recordStepInfo:[NSString stringWithFormat:@"运营商: %@", [carrier carrierName]]];
    }
}

/*!
 *  @brief  获取本地网络环境信息
 */
- (void)recordLocalNetEnvironment
{
    //判断是否联网以及获取网络类型
    NSArray *typeArr = [NSArray arrayWithObjects:@"2G", @"3G", @"4G", @"5G", @"WiFi", nil];
    _curNetType = [LDNetGetAddress getNetworkTypeFromStatusBar];
    if (_curNetType == 0) {
        [self recordStepInfo:@"当前是否联网: 未联网"];
    } else {
        [self recordStepInfo:@"当前是否联网: 已联网"];
        if (_curNetType > 0 && _curNetType < 6) {
            [self recordStepInfo:[NSString stringWithFormat:@"当前联网类型: %@", [typeArr objectAtIndex:_curNetType - 1]]];
        }
    }

    //外网ip
    NSURL *url = [NSURL URLWithString:@"https://api.ipify.org/"];
    NSString *ip = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
    [self recordStepInfo:[NSString stringWithFormat:@"外网IP: %@", ip]];
    
    //本地ip信息
    _localIp = [LDNetGetAddress deviceIPAdress];
    [self recordStepInfo:[NSString stringWithFormat:@"当前本机IP: %@", _localIp]];
    
    if (_curNetType == NETWORK_TYPE_WIFI) {
        _gatewayIp = [LDNetGetAddress getGatewayIPAddress];
        [self recordStepInfo:[NSString stringWithFormat:@"本地网关: %@", _gatewayIp]];
    } else {
        _gatewayIp = @"";
    }

    _dnsServers = [NSArray arrayWithArray:[LDNetGetAddress outPutDNSServers]];
    [self recordStepInfo:[NSString stringWithFormat:@"本地DNS: %@",
                                                    [_dnsServers componentsJoinedByString:@", "]]];
}

- (void)dialogsisEachDomain {
    if (self.currentDomain) {
        [self recordStepInfo:[NSString stringWithFormat:@"\n\n诊断域名: %@", self.currentDomain]];
        
        // host地址IP列表
        long time_start = [LDNetTimer getMicroSeconds];
        _hostAddress = [NSArray arrayWithArray:[LDNetGetAddress getDNSsWithDomain:self.currentDomain]];
        long time_duration = [LDNetTimer computeDurationSince:time_start] / 1000;
        if ([_hostAddress count] == 0) {
            [self recordStepInfo:[NSString stringWithFormat:@"DNS解析结果: 解析失败"]];
        } else {
            [self
             recordStepInfo:[NSString stringWithFormat:@"DNS解析结果: %@ (%ldms)",
                             [_hostAddress componentsJoinedByString:@", "],
                             time_duration]];
        }
        
        if (_isRunning) {
            [self pingDialogsis];
        }
    }
}

/**
 * 构建ping列表并进行ping诊断
 */
- (void)pingDialogsis
{
    if (!_netPinger) {
        _netPinger = [[LDNetPing alloc] init];
        _netPinger.delegate = self;
    }
    
    [self recordStepInfo:@"开始ping..."];
    [_netPinger runWithHostName:self.currentDomain normalPing:YES];
}

- (void)tracerouteDialogsis {
    if (_isRunning) {
        //开始诊断traceRoute
        [self recordStepInfo:@"开始traceroute..."];
        if (!_traceRouter) {
            _traceRouter = [[LDNetTraceRoute alloc] initWithMaxTTL:TRACEROUTE_MAX_TTL
                                                           timeout:TRACEROUTE_TIMEOUT
                                                       maxAttempts:TRACEROUTE_ATTEMPTS
                                                              port:TRACEROUTE_PORT];
            _traceRouter.delegate = self;
        }
        if (_traceRouter) {
            [NSThread detachNewThreadSelector:@selector(doTraceRoute:)
                                     toTarget:_traceRouter
                                   withObject:self.currentDomain];
        }
    }
}

#pragma mark -
#pragma mark - netPingDelegate

- (void)appendPingLog:(NSString *)pingLog
{
    [self recordStepInfo:pingLog];
}

- (void)netPingDidEnd
{
    if (self.needTraceRoute) {
        [self tracerouteDialogsis];
    } else {
        if (_diagnosisDomainIndex >= _domains.count - 1) {
            [self stopNetDialogsis];
        } else {
            _diagnosisDomainIndex++;
            [self dialogsisEachDomain];
        }
    }
}

#pragma mark - traceRouteDelegate
- (void)appendRouteLog:(NSString *)routeLog
{
    [self recordStepInfo:routeLog];
}

- (void)traceRouteDidEnd
{
    if (_diagnosisDomainIndex >= _domains.count - 1) {
        [self stopNetDialogsis];
    } else {
        _diagnosisDomainIndex++;
        [self dialogsisEachDomain];
    }
}

#pragma mark - common method
/**
 * 如果调用者实现了stepInfo接口，输出信息
 */
- (void)recordStepInfo:(NSString *)stepInfo
{
    if (stepInfo == nil) stepInfo = @"";
    [_logInfo appendString:stepInfo];
    [_logInfo appendString:@"\n"];

    if (self.delegate && [self.delegate respondsToSelector:@selector(netDiagnosisStepInfo:)]) {
        [self.delegate netDiagnosisStepInfo:[NSString stringWithFormat:@"%@\n", stepInfo]];
    }
}

- (NSString *)currentDomain {
    if (_diagnosisDomainIndex < _domains.count) {
        return _domains[_diagnosisDomainIndex];
    } else {
        return nil;
    }
}

@end
