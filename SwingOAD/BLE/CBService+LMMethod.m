//
//  CBService+LMMethod.m
//  BabyBluetoothAppDemo
//
//  Created by Mapple on 16/8/20.
//  Copyright © 2016年 zzteam. All rights reserved.
//

#import "CBService+LMMethod.h"

@implementation CBService (LMMethod)

- (CBCharacteristic*)findCharacteristic:(NSString*)uuid {
    for (CBCharacteristic *character in self.characteristics) {
        if ([character.UUID.UUIDString isEqualToString:uuid]) {
            return character;
        }
    }
    return nil;
}

@end
