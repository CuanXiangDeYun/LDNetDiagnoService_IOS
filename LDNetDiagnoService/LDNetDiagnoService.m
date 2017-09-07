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
#import "LDNetGetAddress.h"
#import "LDNetTimer.h"
#import "LDNetConnect.h"
#import "SDVersion.h"
#import "LDJailbreak.h"
#import "LDNetMTR.h"

@interface LDNetDiagnoService () <LDNetPingDelegate, LDNetMTRDelegate> {
    NETWORK_TYPE _curNetType;
    NSString *_localIp;
    NSString *_gatewayIp;
    NSArray *_dnsServers;
    NSArray *_hostAddress;

    NSMutableString *_logInfo;  //记录网络诊断log日志
    BOOL _isRunning;
    LDNetMTR *_mtr;
    
    NSInteger _diagnosisDomainIndex;
    BOOL _hasFetchedNetType;
}

@end

@implementation LDNetDiagnoService
#pragma mark - public method

- (instancetype)init {
    self = [super init];
    if (self) {
        _logInfo = [NSMutableString string];
        _isRunning = NO;
        _diagnosisDomainIndex = 0;
    }
    return self;
}

- (void)startCompleteDiagnosis
{
    if (_isRunning || _domains.count == 0) {
        return;
    }
    
    _isRunning = YES;

    [_logInfo setString:@""];
    [self recordStepInfo:@"开始诊断\n"];
    
    [self getBasicInfo];
    [self startNetDiagnosis];
}

- (void)stopNetDialogsis
{
    _diagnosisDomainIndex = 0;
    if (_isRunning) {
        _isRunning = NO;

        if (_mtr) {
            [_mtr stopMTR];
        }
    }
    [self recordStepInfo:@"\n诊断结束"];
    if ([self.delegate respondsToSelector:@selector(netDiagnosisDidEnd:)]) {
        [self.delegate netDiagnosisDidEnd:_logInfo];
    }
}

- (void)getBasicInfo {
    [self recordCurrentTime];
    [self recordUser];
    [self recordAppVersion];
    [self recordDeviceInfo];
    [self recordNetType];
}

- (void)startNetDiagnosis {
    _isRunning = YES;
    
    [self recordStepInfo:@"\n开始网络诊断"];
    
    if ([self.delegate respondsToSelector:@selector(netDiagnosisDidStarted)]) {
        [self.delegate netDiagnosisDidStarted];
    }
    
    if (!_hasFetchedNetType) {
        [self recordNetType];
    }
    
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
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self recordLocalNetEnvironment]; //检测外网时用了一个同步请求
        [self dialogsisEachDomain];
    });
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
- (void)recordAppVersion
{
    //输出应用和设备信息
    NSDictionary *dicBundle = [[NSBundle mainBundle] infoDictionary];

    [self recordStepInfo:[NSString stringWithFormat:@"应用名称: %@", dicBundle[@"CFBundleDisplayName"]]];
    [self recordStepInfo:[NSString stringWithFormat:@"应用版本: %@", dicBundle[@"CFBundleShortVersionString"]]];
    [self recordStepInfo:[NSString stringWithFormat:@"Build: %@", dicBundle[@"CFBundleVersion"]]];
}

- (void)recordDeviceInfo {
    //输出机器信息
    UIDevice *device = [UIDevice currentDevice];
    [self recordStepInfo:[NSString stringWithFormat:@"设备型号: %@", DeviceVersionNames[[SDVersion deviceVersion]]]];
    [self recordStepInfo:[NSString stringWithFormat:@"系统版本: %@", [device systemVersion]]];
    [self recordStepInfo:[NSString stringWithFormat:@"UUID: %@", self.uuid ?: [[[UIDevice currentDevice] identifierForVendor] UUIDString]]];
    [self recordStepInfo:[NSString stringWithFormat:@"是否越狱: %@", [LDJailbreak isJailbroken] ? @"YES" : @"NO"]];
    
    //运营商信息
    CTTelephonyNetworkInfo *netInfo = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier = [netInfo subscriberCellularProvider];
    if (carrier != NULL) {
        [self recordStepInfo:[NSString stringWithFormat:@"运营商: %@", [carrier carrierName]]];
    }
}

- (void)recordNetType {
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
    
    _hasFetchedNetType = YES;
}

/*!
 *  @brief  获取本地网络环境信息
 */
- (void)recordLocalNetEnvironment
{
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
            [self mtrDialogsis];
        }
    }
}

- (void)mtrDialogsis
{
    if (!_mtr) {
        _mtr = [LDNetMTR new];
        _mtr.delegate = self;
    }
    [_mtr mtrWithHost:self.currentDomain];
}

#pragma mark - mtrDelegate
- (void)appendMTRLog:(NSString *)mtrLog {
    [self recordStepInfo:mtrLog];
}

- (void)mtrDidEnd {
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

    if (self.delegate && [self.delegate respondsToSelector:@selector(diagnosisStepInfo:)]) {
        [self.delegate diagnosisStepInfo:[NSString stringWithFormat:@"%@\n", stepInfo]];
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
