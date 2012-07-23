//
//  Cusb.h
//  bbme
//
//  Created by osoumen on 06/05/01.
//  Copyright 2006 osoumen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/usb/IOUSBLib.h>

@interface Cusb : NSObject {
	IONotificationPortRef		fNotifyPort;
	io_iterator_t				fNewDeviceAddedIter;
	io_iterator_t				fNewDeviceRemovedIter;
	
	IOUSBInterfaceInterface 	**fintf;
	
	UInt8						fBuffer[64];
}

// --- オブジェクトの初期化と破棄

- (id) initVendor:(SInt32)vendor product: (SInt32)product;
- (void) dealloc;

- (IOReturn) configureAnchorDevice:(IOUSBDeviceInterface**)dev;
- (IOReturn) anchorWrite:(IOUSBDeviceInterface **)dev address:(UInt16)address length:(UInt16)length data:(UInt8*)data;
- (IOReturn) findInterfaces:(IOUSBDeviceInterface**)dev;

// --- CUSB機能の実装
- (IOReturn) resetpipe:(UInt8)pipe;
- (SInt32) bulkWrite:(UInt8)pipe buf:(UInt8*)buf size:(UInt32)size;
- (SInt32) bulkRead:(UInt8)pipe buf:(UInt8*)buf size:(UInt32)size;

- (void) printErr:(IOReturn)kr;

@end
