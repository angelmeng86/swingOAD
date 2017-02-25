//
//  BLEDelegate.h
//  Swing
//
//  Created by Mapple on 2016/11/29.
//  Copyright © 2016年 zzteam. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

#define LOG_D(format, ...) NSLog(format, ##__VA_ARGS__)

typedef void (^SwingBluetoothInitDeviceBlock)(NSData *macAddress, NSError *error);
typedef void (^SwingBluetoothScanDeviceBlock)(CBPeripheral *peripheral, NSDictionary *advertisementData, NSError *error);

typedef void (^SwingBluetoothSearchDeviceBlock)(CBPeripheral *peripheral, NSError *error);
typedef void (^SwingBluetoothSyncDeviceBlock)(NSMutableArray *activities, NSError *error);

typedef void (^SwingBluetoothUpdateDeviceBlock)(float percent, NSString *remainTime);

@interface BLEDelegate : NSObject<CBCentralManagerDelegate, CBPeripheralDelegate>

@end
