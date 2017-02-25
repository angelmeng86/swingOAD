//
//  BLEUpdater.h
//  Swing
//
//  Created by Mapple on 2017/2/24.
//  Copyright © 2017年 zzteam. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

#define OAD_SERVICE_UUID @"0xF000FFC0-0451-4000-B000-000000000000"
#define OAD_IMAGE_NOTIFY_UUID @"0xF000FFC1-0451-4000-B000-000000000000"
#define OAD_IMAGE_BLOCK_REQUEST_UUID @"0xF000FFC2-0451-4000-B000-000000000000"

@protocol BLEUpdaterDelegate <NSObject>

- (BOOL)deviceUpdate:(CBPeripheral*)peripheral version:(NSString*)version;
- (void)deviceUpdate:(CBPeripheral*)peripheral progress:(float)percent remainTime:(NSString*)text;
- (void)deviceUpdate:(CBPeripheral*)peripheral result:(BOOL)success;

@end

@interface BLEUpdater : NSObject

@property (nonatomic, weak) id delegate;
@property (nonatomic, retain) CBPeripheral* peripheral;

@property (nonatomic) float percent;
@property (nonatomic, strong) NSString *time;

@property uint16_t imgVersion;

+ (void)setImageFile:(NSString*)path;

- (BOOL)needUpdate;
- (BOOL)supportUpdate;

- (BOOL)isUpdating;

- (void)startUpdate;
- (NSString*)curVersion;
- (void)cancelUpdate;

- (void)didDiscoverServices:(CBService *)service;
- (void)didDiscoverCharacteristicsForService:(CBService *)service;

- (void)didUpdateValueForProfile:(CBCharacteristic *)characteristic;
- (void)deviceDisconnected:(CBPeripheral *)peripheral;

@end
