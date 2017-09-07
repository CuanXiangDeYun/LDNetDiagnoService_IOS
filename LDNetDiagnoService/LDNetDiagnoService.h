//
//  LDNetDiagnoService.h
//  LDNetDiagnoServieDemo
//
//  Created by 庞辉 on 14-10-29.
//  Copyright (c) 2014年 庞辉. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 * @protocol 监控网络诊断的过程信息
 *
 */
@protocol LDNetDiagnoServiceDelegate <NSObject>
@optional
/**
 * 逐步返回监控信息，
 * 如果需要实时显示诊断数据，实现此接口方法
 */
- (void)diagnosisStepInfo:(NSString *)stepInfo;


- (void)netDiagnosisDidStarted;

/**
 * 因为监控过程是一个异步过程，当监控结束后告诉调用者；
 * 在监控结束的时候，对监控字符串进行处理
 */
- (void)netDiagnosisDidEnd:(NSString *)allLogInfo;

@end


/**
 * @class 网络诊断服务
 * 通过对指定域名进行ping诊断和traceRoute诊断收集诊断日志
 */
@interface LDNetDiagnoService : NSObject {
}
@property (nonatomic, weak) id<LDNetDiagnoServiceDelegate> delegate;
@property (nonatomic, copy) NSArray *domains;  //接口域名
@property (nonatomic, copy) NSString *userId;  //用户id
@property (nonatomic, copy) NSString *uuid;    //默认取identifierForVendor

/**
 * 开始完整诊断，包括基本信息和网络两部分
 */
- (void)startCompleteDiagnosis;

/**
 * 仅获取应用和设备基本信息
 */
- (void)getBasicInfo;
/**
 * 仅进行网络诊断
 */
- (void)startNetDiagnosis;

/**
 * 停止网络诊断
 */
- (void)stopNetDialogsis;

@end
