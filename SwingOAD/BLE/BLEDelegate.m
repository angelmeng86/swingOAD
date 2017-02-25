//
//  BLEDelegate.m
//  Swing
//
//  Created by Mapple on 2016/11/29.
//  Copyright © 2016年 zzteam. All rights reserved.
//

#import "BLEDelegate.h"

@implementation BLEDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    switch (central.state) {
        case CBManagerStatePoweredOn:
            LOG_D(@"Bluetooth power on.");
            break;
        case CBManagerStatePoweredOff:
            LOG_D(@"Bluetooth pwoer off.");
            break;
        default:
            break;
    }
}

- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary<NSString *, id> *)dict {
    LOG_D(@"willRestoreState:%@", dict);
}

@end
