//
//  CBService+LMMethod.h
//  BabyBluetoothAppDemo
//
//  Created by Mapple on 16/8/20.
//  Copyright © 2016年 刘彦玮. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface CBService (LMMethod)

- (CBCharacteristic*)findCharacteristic:(NSString*)uuid;

@end
