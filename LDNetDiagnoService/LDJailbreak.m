//
//  LDJailbreak.m
//  LDNetDiagnoService
//
//  Created by XuNing on 16/6/1.
//  Copyright © 2016年 庞辉. All rights reserved.
//

#import "LDJailbreak.h"

@implementation LDJailbreak

+ (BOOL)isJailbroken {
    FILE *f = fopen("/bin/bash", "r");
    BOOL isJailbroken = NO;
    if (f != NULL)
        // Device is jailbroken
        isJailbroken = YES;
    else
        // Device isn't jailbroken
        isJailbroken = NO;
    
    fclose(f);
    
    return isJailbroken;
}

@end
