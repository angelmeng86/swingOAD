//
//  ViewController.m
//  SwingOAD
//
//  Created by Mapple on 2017/2/25.
//  Copyright © 2017年 Maple. All rights reserved.
//

#import "ViewController.h"
#import "DeviceTableViewCell.h"
#import "oad.h"
#import "BLEDelegate.h"
#include "BLEUpdater.h"

@interface ViewController ()<UIActionSheetDelegate>

@property (nonatomic, strong) CBCentralManager *manager;

@property (nonatomic, strong) NSMutableArray *peripherals;
@property (nonatomic, strong) NSMutableDictionary *updaters;

@property (nonatomic, strong) NSString *fileName;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Start Scan" style:UIBarButtonItemStylePlain target:self action:@selector(scanAction:)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Select Image" style:UIBarButtonItemStylePlain target:self action:@selector(imageAction:)];
    NSMutableString *path= [[NSMutableString  alloc] initWithString: [[NSBundle mainBundle] resourcePath]];
    [path appendString:@"/"];
    [path appendString:@"A-super-MP-OTA-64M-022317.bin"];
    self.fileName = @"A-super-MP-OTA-64M-022317.bin";
    [BLEUpdater setImageFile:path];
    self.manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    self.peripherals = [NSMutableArray array];
    self.updaters = [NSMutableDictionary dictionary];
}

- (void)imageAction:(UIBarButtonItem*)sender
{
    UIActionSheet *selectImageActionSheet = [[UIActionSheet alloc]initWithTitle:@"Select image from" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Internal Image ...",@"Shared files ...",nil];
    selectImageActionSheet.tag = 0;
    [selectImageActionSheet showInView:self.view];
    
    /*
    if ([sender.title isEqualToString:@"ImageA"]) {
        sender.title = @"ImageB";
        NSMutableString *path= [[NSMutableString  alloc] initWithString: [[NSBundle mainBundle] resourcePath]];
                [path appendString:@"/"];
                [path appendString:@"B-super-MP-OTA-64M-022317.bin"];
        [BLEUpdater setImageFile:path];
    }
    else {
        sender.title = @"ImageA";
        NSMutableString *path= [[NSMutableString  alloc] initWithString: [[NSBundle mainBundle] resourcePath]];
        [path appendString:@"/"];
        [path appendString:@"A-super-MP-OTA-64M-022317.bin"];
        [BLEUpdater setImageFile:path];
    }
     */
}

- (void)scanAction:(UIBarButtonItem*)sender
{
    if ([sender.title isEqualToString:@"Start Scan"]) {
        sender.title = @"Stop Scan";
         [self.manager scanForPeripheralsWithServices:nil options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@YES}];
    }
    else {
        sender.title = @"Start Scan";
        [self.manager stopScan];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _peripherals.count;
}

- (NSString*)deviceState:(CBPeripheral*)device
{
    NSString *text = @"NotConnect";
    switch (device.state) {
        case CBPeripheralStateConnecting:
            text = @"Connecting";
        case CBPeripheralStateConnected:
            text = @"Connected";
        default:
            break;
    }
    BLEUpdater *updater = self.updaters[device];
    if (updater && updater.imgVersion != 0xFFFF) {
        if (updater.isUpdating) {
            text = [NSString stringWithFormat:@"Updating(Ver %04hx)", updater.imgVersion];
        }
        else {
            text = [NSString stringWithFormat:@"%@(Ver %04hx)", text, updater.imgVersion];
        }
    }
    return text;
}

- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [@"Image:" stringByAppendingString:self.fileName];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"DeviceCell";
    DeviceTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    CBPeripheral *peripheral = [_peripherals objectAtIndex:indexPath.row];
    cell.titileLabel.text = peripheral.name;
    cell.detailLabel.text = [self deviceState:peripheral];
    BLEUpdater *updater = self.updaters[peripheral];
    cell.progressView.hidden = updater == nil;
    cell.timeLabel.hidden = cell.progressView.hidden;
    if (updater) {
        cell.progressView.progress = updater.percent;
        cell.timeLabel.text = updater.time;
    }
    return cell;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    CBPeripheral *peripheral = _peripherals[indexPath.row];
    if (peripheral.state != CBPeripheralStateConnected) {
        [self.manager connectPeripheral:peripheral options:nil];
    }
    else {
        [self.manager cancelPeripheralConnection:peripheral];
    }
}

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

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI {
    LOG_D(@"didDiscoverPeripheral:%@ advertisementData:%@ RSSI:%@", peripheral, advertisementData, RSSI);
    if ([peripheral.name.uppercaseString hasPrefix:@"SWING"]) {
        if (![_peripherals containsObject:peripheral]) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_peripherals.count inSection:0];
            [_peripherals addObject:peripheral];
            [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral{
    LOG_D(@"didConnectPeripheral:%@", peripheral);
    if(!self.updaters[peripheral])
    {
        BLEUpdater *updater = [[BLEUpdater alloc] init];
        self.updaters[peripheral] = updater;
        updater.peripheral = peripheral;
        updater.delegate = self;
    }
    peripheral.delegate = self;
    NSArray *services = @[[CBUUID UUIDWithString:OAD_SERVICE_UUID]];
    [peripheral discoverServices:services];
    [self reloadPeripheralCell:peripheral];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error{
    LOG_D(@"didFailToConnectPeripheral:%@ error:%@", peripheral, error);
    [self reloadPeripheralCell:peripheral];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    LOG_D(@"didDisconnectPeripheral:%@ error:%@", peripheral, error);
    BLEUpdater *updater = self.updaters[peripheral];
    [updater deviceDisconnected:peripheral];
    if (updater) {
        [self.updaters removeObjectForKey:peripheral];
        [self reloadPeripheralCell:peripheral];
    }
}

//
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(nullable NSError *)error {
    LOG_D(@"didDiscoverServices:%@ error:%@", peripheral, error);
    if (error) {
        return;
    }
    BLEUpdater *updater = self.updaters[peripheral];
    for (CBService *s in peripheral.services) {
        LOG_D(@"service UUID %@", s.UUID.UUIDString);
        [updater didDiscoverServices:s];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(nullable NSError *)error {
    LOG_D(@"didDiscoverCharacteristicsForService:%@ error:%@", peripheral, error);
    if (error) {
        return;
    }
    BLEUpdater *updater = self.updaters[peripheral];
    [updater didDiscoverCharacteristicsForService:service];
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error {
    LOG_D(@"didWriteValueForCharacteristic:%@ characteristic:%@ error:%@", peripheral, characteristic, error);
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error {
    LOG_D(@"didUpdateValueForCharacteristic:%@ characteristic:%@ error:%@", peripheral, characteristic, error);
    if (error) {
        return;
    }
    BLEUpdater *updater = self.updaters[peripheral];
    [updater didUpdateValueForProfile:characteristic];
}

- (void)reloadPeripheralCell:(CBPeripheral*)peripheral
{
    NSUInteger index =  [self.peripherals indexOfObject:peripheral];
    if(NSNotFound != index)
    {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (BOOL)deviceUpdate:(CBPeripheral*)peripheral version:(NSString*)version
{
    [self reloadPeripheralCell:peripheral];
    return YES;
}


- (void)deviceUpdate:(CBPeripheral*)peripheral progress:(float)percent remainTime:(NSString*)text
{
     [self reloadPeripheralCell:peripheral];
}

- (void)deviceUpdate:(CBPeripheral*)peripheral result:(BOOL)success
{
    [self reloadPeripheralCell:peripheral];
}

-(void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSLog(@"Button clicked : %d",buttonIndex);
    switch (actionSheet.tag) {
        case 0: {
            switch(buttonIndex) {
                case 0: {
                    UIActionSheet *selectInternalFirmwareSheet = [[UIActionSheet alloc]initWithTitle:@"Select Firmware image" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"A-super-MP-OTA-64M-022317",@"B-super-MP-OTA-64M-022317", nil];
                    selectInternalFirmwareSheet.tag = 1;
                    [selectInternalFirmwareSheet showInView:self.view];
                    break;
                }
                case 1: {
                    NSMutableArray *files = [self findFWFiles];
                    UIActionSheet *selectSharedFileFirmware = [[UIActionSheet alloc]init];
                    selectSharedFileFirmware.title = @"Select Firmware image";
                    selectSharedFileFirmware.tag = 2;
                    selectSharedFileFirmware.delegate = self;
                    
                    for (NSString *fileName in files) {
                        [selectSharedFileFirmware addButtonWithTitle:[fileName lastPathComponent]];
                    }
                    [selectSharedFileFirmware addButtonWithTitle:@"Cancel"];
                    selectSharedFileFirmware.cancelButtonIndex = selectSharedFileFirmware.numberOfButtons - 1;
                    [selectSharedFileFirmware showInView:self.view];
                    break;
                }
            }
            break;
        }
        case 1: {
            switch (buttonIndex) {
                case 0: {
                    NSMutableString *path= [[NSMutableString  alloc] initWithString: [[NSBundle mainBundle] resourcePath]];
                    [path appendString:@"/"] ;
                    [path appendString:@"A-super-MP-OTA-64M-022317.bin"];
                    self.fileName = @"A-super-MP-OTA-64M-022317.bin";
                    [BLEUpdater setImageFile:path];
                    [self.tableView reloadData];
                    break;
                }
                case 1: {
                    NSMutableString *path= [[NSMutableString  alloc] initWithString: [[NSBundle mainBundle] resourcePath]];
                    [path appendString:@"/"] ;
                    [path appendString:@"B-super-MP-OTA-64M-022317.bin"];
                    self.fileName = @"B-super-MP-OTA-64M-022317.bin";
                    [BLEUpdater setImageFile:path];
                    [self.tableView reloadData];
                    break;
                }
                default:
                    break;
            }
            break;
        }
        case 2: {
            if (buttonIndex == actionSheet.numberOfButtons - 1) break;
            NSMutableArray *files = [self findFWFiles];
            NSString *fileName = [files objectAtIndex:buttonIndex];
            self.fileName = [fileName lastPathComponent];
            [BLEUpdater setImageFile:fileName];
            [self.tableView reloadData];
            break;
        }
        default:
            break;
    }
}

-(NSMutableArray *) findFWFiles {
    NSMutableArray *FWFiles = [[NSMutableArray alloc]init];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory,NSUserDomainMask, YES);
    NSString *publicDocumentsDir = [paths objectAtIndex:0];
    
    NSError *error;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:publicDocumentsDir error:&error];
    
    
    if (files == nil) {
        NSLog(@"Could not find any firmware files ...");
        return FWFiles;
    }
    for (NSString *file in files) {
        if ([file.pathExtension compare:@"bin" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
            NSString *fullPath = [publicDocumentsDir stringByAppendingPathComponent:file];
            [FWFiles addObject:fullPath];
        }
    }
    
    return FWFiles;
}


@end
