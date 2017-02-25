//
//  BLEUpdater.m
//  Swing
//
//  Created by Mapple on 2017/2/24.
//  Copyright © 2017年 zzteam. All rights reserved.
//

#import "BLEUpdater.h"
#import "BLEUtility.h"
#import "CBService+LMMethod.h"
#import "BLEDelegate.h"
#import "oad.h"

typedef enum : NSUInteger {
    BLEUpdaterStateNone,
    BLEUpdaterStateDiscover,
    BLEUpdaterStateGetVersion,
    BLEUpdaterStateOk,
    BLEUpdaterStateProgramming,
} BLEUpdaterState;

@interface BLEUpdater ()

@property int nBlocks;
@property int nBytes;
@property int iBlocks;
@property int iBytes;

@property int state;

@property (nonatomic, strong) NSData* imageData;

@end

@implementation BLEUpdater

static NSData* gImageData = nil;

+ (void)setImageFile:(NSString*)path
{
    //固件版本
    gImageData = [NSData dataWithContentsOfFile:path];
    LOG_D(@"Loaded firmware \"%@\"of size : %ld",path, (unsigned long)gImageData.length);
}

+ (NSData*)imageData
{
    return gImageData;
}

- (id)init
{
    if (self = [super init]) {
        self.state = BLEUpdaterStateNone;
        //固件版本
//        NSMutableString *path= [[NSMutableString  alloc] initWithString: [[NSBundle mainBundle] resourcePath]];
//        [path appendString:@"/"];
//        [path appendString:imageA ? @"A-super-MP-OTA-64M-022317.bin" : @"B-super-MP-OTA-64M-022317.bin"];
//        self.imageData = [NSData dataWithContentsOfFile:path];
//        LOG_D(@"Loaded firmware \"%@\"of size : %ld",path, (unsigned long)self.imageData.length);
        
        self.imgVersion = 0xFFFF;
    }
    return self;
}

- (void)startUpdate
{
    if ([self isCorrectImage]) {
        [self uploadImage];
    }
}

- (BOOL)supportUpdate
{
    return self.state > BLEUpdaterStateNone;
}

- (NSString*)curVersion
{
    if (self.imgVersion != 0xFFFF) {
        return [NSString stringWithFormat:@"%04hx", self.imgVersion];
    }
    return nil;
}

- (BOOL)needUpdate
{
    if (self.state == BLEUpdaterStateOk) {
        return [self isCorrectImage];
    }
    return NO;
}

- (BOOL)isUpdating
{
    return self.state == BLEUpdaterStateProgramming;
}

- (void)cancelUpdate
{
    self.state = BLEUpdaterStateNone;
}

- (void)didDiscoverServices:(CBService *)service
{
    if ([service.UUID isEqual:[CBUUID UUIDWithString:OAD_SERVICE_UUID]]) {
        self.state = BLEUpdaterStateDiscover;
        [self.peripheral discoverCharacteristics:nil forService:service];
    }
}

- (void)didDiscoverCharacteristicsForService:(CBService *)service
{
    if ([service.UUID isEqual:[CBUUID UUIDWithString:OAD_SERVICE_UUID]]) {
        self.state = BLEUpdaterStateGetVersion;
        [self configureProfile];
    }
}

- (void)didUpdateValueForProfile:(CBCharacteristic *)characteristic
{
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:OAD_IMAGE_NOTIFY_UUID]]) {
        if (self.imgVersion == 0xFFFF) {
            unsigned char data[characteristic.value.length];
            [characteristic.value getBytes:&data length:characteristic.value.length];
            self.imgVersion = ((uint16_t)data[1] << 8 & 0xff00) | ((uint16_t)data[0] & 0xff);
            LOG_D(@"self.imgVersion : %04hx",self.imgVersion);
            self.state = BLEUpdaterStateOk;
            if ([_delegate respondsToSelector:@selector(deviceUpdate:version:)]) {
                if ([_delegate deviceUpdate:_peripheral version:[NSString stringWithFormat:@"%04hx", self.imgVersion]]) {
                    if ([self isCorrectImage]) {
                        [self uploadImage];
                    }
                    else {
                        if ([_delegate respondsToSelector:@selector(deviceUpdate:result:)]) {
                            [_delegate deviceUpdate:_peripheral result:NO];
                        }
                    }
                }
            }
        }
        LOG_D(@"OAD Image notify : %@",characteristic.value);
    }
}

- (void)deviceDisconnected:(CBPeripheral *)peripheral
{
    if ([peripheral isEqual:self.peripheral]) {
        self.state = BLEUpdaterStateNone;
//        if ([_delegate respondsToSelector:@selector(deviceUpdateResult:)]) {
//            [_delegate deviceUpdateResult:NO];
//        }
    }
}

- (void)configureProfile {
    LOG_D(@"Configurating OAD Profile");
    CBUUID *sUUID = [CBUUID UUIDWithString:OAD_SERVICE_UUID];
    CBUUID *cUUID = [CBUUID UUIDWithString:OAD_IMAGE_NOTIFY_UUID];
    //监听OAD_IMAGE_NOTIFY_UUID反馈数据
    [BLEUtility setNotificationForCharacteristic:self.peripheral sCBUUID:sUUID cCBUUID:cUUID enable:YES];
    //发送0x00要更新Image B，如果不回应则1.5s后发0x01要更新Image A
    unsigned char data = 0x00;
    [BLEUtility writeCharacteristic:self.peripheral sCBUUID:sUUID cCBUUID:cUUID data:[NSData dataWithBytes:&data length:1]];
    [NSTimer scheduledTimerWithTimeInterval:1.5f target:self selector:@selector(imageDetectTimerTick:) userInfo:nil repeats:NO];
    self.imgVersion = 0xFFFF;
}

//-(void) deconfigureProfile {
//    NSLog(@"Deconfiguring OAD Profile");
//    CBUUID *sUUID = [CBUUID UUIDWithString:OAD_SERVICE_UUID];
//    CBUUID *cUUID = [CBUUID UUIDWithString:OAD_IMAGE_NOTIFY_UUID];
//    [BLEUtility setNotificationForCharacteristic:self.peripheral sCBUUID:sUUID cCBUUID:cUUID enable:YES];
//}

- (BOOL)isCorrectImage {
    self.imageData = BLEUpdater.imageData;
    if (!self.imageData || self.imgVersion == 0xFFFF) {
        return NO;
    }
    
//    unsigned char imageFileData[self.imageData.length];
//    [self.imageData getBytes:imageFileData length:self.imageData.length];
    
    img_hdr_t imgHeader;
    memcpy(&imgHeader, self.imageData.bytes + OAD_IMG_HDR_OSET, sizeof(img_hdr_t));
    
//    if ((imgHeader.ver & 0x01) != (self.imgVersion & 0x01)) return YES;
    if (imgHeader.ver != self.imgVersion) return YES;
    return NO;
}

- (void)imageDetectTimerTick:(NSTimer *)timer {
    if(self.state != BLEUpdaterStateGetVersion) {
        LOG_D(@"imageDetectTimerTick invalid.");
        return;
    }
    //IF we have come here, the image userID is B.
    LOG_D(@"imageDetectTimerTick:");
    CBUUID *sUUID = [CBUUID UUIDWithString:OAD_SERVICE_UUID];
    CBUUID *cUUID = [CBUUID UUIDWithString:OAD_IMAGE_NOTIFY_UUID];
    unsigned char data = 0x01;
    [BLEUtility writeCharacteristic:self.peripheral sCBUUID:sUUID cCBUUID:cUUID data:[NSData dataWithBytes:&data length:1]];
}

- (void) uploadImage {
    self.state = BLEUpdaterStateProgramming;

//    unsigned char imageFileData[self.imageData.length];
//    [self.imageData getBytes:imageFileData length:self.imageData.length];
    const void *pData = self.imageData.bytes;
    uint8_t requestData[OAD_IMG_HDR_SIZE + 2 + 2]; // 12Bytes
    
    img_hdr_t imgHeader;
    memcpy(&imgHeader, pData + OAD_IMG_HDR_OSET, sizeof(img_hdr_t));
    
    
    
    requestData[0] = LO_UINT16(imgHeader.ver);
    requestData[1] = HI_UINT16(imgHeader.ver);
    
    requestData[2] = LO_UINT16(imgHeader.len);
    requestData[3] = HI_UINT16(imgHeader.len);
    
    LOG_D(@"Image version = %04hx, len = %04hx",imgHeader.ver,imgHeader.len);
    
    memcpy(requestData + 4, &imgHeader.uid, sizeof(imgHeader.uid));
    
    requestData[OAD_IMG_HDR_SIZE + 0] = LO_UINT16(12);
    requestData[OAD_IMG_HDR_SIZE + 1] = HI_UINT16(12);
    
    requestData[OAD_IMG_HDR_SIZE + 2] = LO_UINT16(15);
    requestData[OAD_IMG_HDR_SIZE + 1] = HI_UINT16(15);
    
    CBUUID *sUUID = [CBUUID UUIDWithString:OAD_SERVICE_UUID];
    CBUUID *cUUID = [CBUUID UUIDWithString:OAD_IMAGE_NOTIFY_UUID];
    
    [BLEUtility writeCharacteristic:self.peripheral sCBUUID:sUUID cCBUUID:cUUID data:[NSData dataWithBytes:requestData length:OAD_IMG_HDR_SIZE + 2 + 2]];
    
    self.nBlocks = imgHeader.len / (OAD_BLOCK_SIZE / HAL_FLASH_WORD_SIZE);
    self.nBytes = imgHeader.len * HAL_FLASH_WORD_SIZE;
    self.iBlocks = 0;
    self.iBytes = 0;
    
    
    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(programmingTimerTick:) userInfo:nil repeats:NO];
    
}

-(void) programmingTimerTick:(NSTimer *)timer {
    if (self.state != BLEUpdaterStateProgramming || self.peripheral.state != CBPeripheralStateConnected) {
        return;
    }
    
//    unsigned char imageFileData[self.imageData.length];
//    [self.imageData getBytes:imageFileData length:self.imageData.length];
    const void *pData = self.imageData.bytes;
    
    //Prepare Block
    uint8_t requestData[2 + OAD_BLOCK_SIZE];
    
    // This block is run 4 times, this is needed to get CoreBluetooth to send consequetive packets in the same connection interval.
    for (int ii = 0; ii < 4; ii++) {
        
        requestData[0] = LO_UINT16(self.iBlocks);
        requestData[1] = HI_UINT16(self.iBlocks);
        
        memcpy(&requestData[2] , pData + self.iBytes, OAD_BLOCK_SIZE);
        
        CBUUID *sUUID = [CBUUID UUIDWithString:OAD_SERVICE_UUID];
        CBUUID *cUUID = [CBUUID UUIDWithString:OAD_IMAGE_BLOCK_REQUEST_UUID];
        
        [BLEUtility writeNoResponseCharacteristic:self.peripheral sCBUUID:sUUID cCBUUID:cUUID data:[NSData dataWithBytes:requestData length:2 + OAD_BLOCK_SIZE]];
        
        self.iBlocks++;
        self.iBytes += OAD_BLOCK_SIZE;
        
        if(self.iBlocks == self.nBlocks) {
            self.state = BLEUpdaterStateNone;
            if ([_delegate respondsToSelector:@selector(deviceUpdate:result:)]) {
                [_delegate deviceUpdate:_peripheral result:YES];
            }
            return;
        }
        else {
            if (ii == 3)[NSTimer scheduledTimerWithTimeInterval:0.09 target:self selector:@selector(programmingTimerTick:) userInfo:nil repeats:NO];
        }
    }
    
    if ([_delegate respondsToSelector:@selector(deviceUpdate:progress:remainTime:)]) {
        float secondsPerBlock = 0.09 / 4;
        float secondsLeft = (float)(self.nBlocks - self.iBlocks) * secondsPerBlock;
        self.percent = (float)((float)self.iBlocks / (float)self.nBlocks);
        self.time = [NSString stringWithFormat:@"%d:%02d",(int)(secondsLeft / 60),(int)secondsLeft - (int)(secondsLeft / 60) * (int)60];
        [_delegate deviceUpdate:_peripheral progress:_percent remainTime:_time];
    }
    
    LOG_D(@". iBlocks %d / nBlocks %d", self.iBlocks, self.nBlocks);
}

@end
