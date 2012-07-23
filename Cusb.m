//
//  Cusb.m
//  bbme
//
//  Created by osoumen on 06/05/01.
//  Copyright 2006 osoumen. All rights reserved.
//

#import "Cusb.h"
#import <IOKit/IOCFPlugIn.h>
#import <IOKit/hid/IOHIDDevicePlugIn.h>
#import <mach/mach.h>
#import <unistd.h>

static void NewDeviceAdded(void *refCon, io_iterator_t iterator);
static void NewDeviceRemoved(void *refCon, io_iterator_t iterator);

@implementation Cusb

- (id) initVendor:(SInt32)vendor product: (SInt32)product
{
	if([super init] == nil) return nil;

	mach_port_t				masterPort    = 0;
	CFMutableDictionaryRef  matchingDict  = 0;
	CFRunLoopSourceRef		runLoopSource = 0;
	kern_return_t			result;

	fNotifyPort           = 0;
	fNewDeviceAddedIter   = 0;
	fNewDeviceRemovedIter = 0;
	
	// IOMasterPortを取得する。
	result = IOMasterPort(MACH_PORT_NULL, &masterPort);
	if(result || !masterPort) goto bail;

	// デバイスのマッチング用の辞書を作成する。
	matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
	if(!matchingDict) goto bail;
	
	// Notification Portを生成し、それをRun Loop Sourceへ登録する。
	fNotifyPort   = IONotificationPortCreate(masterPort);
	runLoopSource = IONotificationPortGetRunLoopSource(fNotifyPort);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
	
	// 辞書にファームウェアのダウンロード後のベンダーIDとプロダクトIDを登録する。
	CFDictionarySetValue(matchingDict, 
						 CFSTR(kUSBVendorID), 
						 CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &vendor)); 
	CFDictionarySetValue(matchingDict, 
						 CFSTR(kUSBProductID), 
						 CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &product)); 

	matchingDict = (CFMutableDictionaryRef)CFRetain(matchingDict); 
	matchingDict = (CFMutableDictionaryRef)CFRetain(matchingDict); 
	
	// ノーティフィケーションを設定する。
	result = IOServiceAddMatchingNotification(fNotifyPort,
											  kIOFirstMatchNotification,
											  matchingDict,
											  NewDeviceAdded,
											  (void*)self,
											  &fNewDeviceAddedIter);
	result = IOServiceAddMatchingNotification(fNotifyPort,
											  kIOTerminatedNotification,
											  matchingDict,
											  NewDeviceRemoved,
											  (void*)self,
											  &fNewDeviceRemovedIter);
	NewDeviceRemoved((void*)self, fNewDeviceRemovedIter);
	NewDeviceAdded((void*)self, fNewDeviceAddedIter);

	// IOMasterPortを破棄する。
	mach_port_deallocate(mach_task_self(), masterPort);
	masterPort = 0;
	return self;
	
bail:
	[self dealloc];
	if(masterPort) {
		mach_port_deallocate(mach_task_self(), masterPort);
		masterPort = 0;
	}
	return nil;
}


- (void) dealloc
{
    if(fNotifyPort) {
		IONotificationPortDestroy(fNotifyPort);
		fNotifyPort = 0;
	}
    if(fNewDeviceAddedIter) {
        IOObjectRelease(fNewDeviceAddedIter);
        fNewDeviceAddedIter = 0;
    }
    if(fNewDeviceRemovedIter) {
        IOObjectRelease(fNewDeviceRemovedIter);
        fNewDeviceRemovedIter = 0;
    }
	[super dealloc];
}


- (IOReturn) configureAnchorDevice:(IOUSBDeviceInterface**)dev
{
    UInt8							numConf;
    IOReturn						kr;
    IOUSBConfigurationDescriptorPtr	confDesc;
    
    kr = (*dev)->GetNumberOfConfigurations(dev, &numConf);
    if(!numConf) {
        return -1;
	}
    
    // コンフィグレーション・ディスクリプタを取得する。
    kr = (*dev)->GetConfigurationDescriptorPtr(dev, 0, &confDesc);
    if(kr) {
        return kr;
    }
	kr = (*dev)->SetConfiguration(dev, confDesc->bConfigurationValue);
	if(kr) {
		[self printErr:kr];
		return kr;
    }
    return kIOReturnSuccess;
}


- (IOReturn) anchorWrite:(IOUSBDeviceInterface **)dev address:(UInt16)address length:(UInt16)length data:(UInt8*)data
{
    IOUSBDevRequest request;
    request.bmRequestType = USBmakebmRequestType(kUSBOut, kUSBVendor, kUSBDevice);
    request.bRequest      = 0xa0;
    request.wValue        = address;
    request.wIndex        = 0;
    request.wLength       = length;
    request.pData         = data;
    return (*dev)->DeviceRequest(dev, &request);
}

#define IID_IGimic CFUUIDGetConstantUUIDWithBytes(NULL,	\
0x17, 0x5c, 0x7d, 0xa0, 0x8a, 0xa5, 0x41, 0x73,			\
0x96, 0xda, 0xbb, 0x43, 0xb8, 0xeb, 0x8f, 0x17)

#define IID_IGimic2 CFUUIDGetConstantUUIDWithBytes(NULL,\
0x47, 0x14, 0x1a, 0x01, 0x15, 0xf5, 0x4b, 0xf5,			\
0x95, 0x54, 0xca, 0x7a, 0xac, 0xd5, 0x4b, 0xb8)

- (IOReturn) findInterfaces:(IOUSBDeviceInterface**)dev
{
    IOReturn					kr;
    IOUSBFindInterfaceRequest	request;
    io_iterator_t				iterator;
    io_service_t				usbInterface;
    IOCFPlugInInterface			**plugInInterface = NULL;
    IOUSBInterfaceInterface 	**intf = NULL;
    HRESULT						res;
    SInt32						score;
    
    request.bInterfaceClass    = kIOUSBFindInterfaceDontCare;
    request.bInterfaceSubClass = kIOUSBFindInterfaceDontCare;
    request.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;
    request.bAlternateSetting  = kIOUSBFindInterfaceDontCare;
   
    kr = (*dev)->CreateInterfaceIterator(dev, &request, &iterator);
    
    while((usbInterface = IOIteratorNext(iterator))) {
        kr = IOCreatePlugInInterfaceForService(usbInterface, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID, &plugInInterface, &score);
        kr = IOObjectRelease(usbInterface);
        if((kIOReturnSuccess != kr) || !plugInInterface) {
            break;
        }
            
        // デバイス・インターフェースから、さらにインターフェースを取得する。
        res = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID), (LPVOID) &intf);
        (*plugInInterface)->Release(plugInInterface);
        if(res || !intf) {
            break;
        }
		fintf = intf;
        
		// インターフェースをオープンする。
        kr = (*intf)->USBInterfaceOpen(intf);
        if(kIOReturnSuccess != kr) {
			/*
			NSLog(@"USBInterfaceOpen error.");
			[self printErr:kr];
			*/
            (void) (*intf)->Release(intf);
            continue;
        }
		
		// 最初に見つかったインターフェースだけを処理する。
		//Get the number of endpoints associated with this interface
		UInt8                       interfaceNumEndpoints;
        kr = (*intf)->GetNumEndpoints(intf, &interfaceNumEndpoints);
        if (kr != kIOReturnSuccess) {
            printf("Unable to get number of endpoints (%08x)\n", kr);
            (void) (*intf)->USBInterfaceClose(intf);
            (void) (*intf)->Release(intf);
            break;
        }
		printf("Interface has %d endpoints\n", interfaceNumEndpoints);

		int		pipeRef;
		for (pipeRef = 1; pipeRef <= interfaceNumEndpoints; pipeRef++)
        {
            IOReturn        kr2;
            UInt8           direction;
            UInt8           number;
            UInt8           transferType;
            UInt16          maxPacketSize;
            UInt8           interval;
            char            *message;
			
            kr2 = (*intf)->GetPipeProperties(intf,
												  pipeRef, &direction,
												  &number, &transferType,
												  &maxPacketSize, &interval);
            if (kr2 != kIOReturnSuccess)
                printf("Unable to get properties of pipe %d (%08x)\n",
					   pipeRef, kr2);
            else
            {
                printf("PipeRef %d: ", pipeRef);
                switch (direction)
                {
                    case kUSBOut:
                        message = "out";
                        break;
                    case kUSBIn:
                        message = "in";
                        break;
                    case kUSBNone:
                        message = "none";
                        break;
                    case kUSBAnyDirn:
                        message = "any";
                        break;
                    default:
                        message = "???";
                }
                printf("direction %s, ", message);
				
                switch (transferType)
                {
                    case kUSBControl:
                        message = "control";
                        break;
                    case kUSBIsoc:
                        message = "isoc";
                        break;
                    case kUSBBulk:
                        message = "bulk";
                        break;
                    case kUSBInterrupt:
                        message = "interrupt";
                        break;
                    case kUSBAnyType:
                        message = "any";
                        break;
                    default:
                        message = "???";
                }
                printf("transfer type %s, maxPacketSize %d\n", message,
					   maxPacketSize);
            }
        }
		
        break;
    }
    return kr;
}

- (IOReturn) resetpipe:(UInt8)pipe
{
	IOReturn			kr = noErr;
	
	kr = (*fintf)->ResetPipe(fintf,pipe);

	return kr;
}

- (SInt32) bulkWrite:(UInt8)pipe buf:(UInt8*)buf size:(UInt32)size
{
	IOReturn			kr = noErr;
	UInt32				len = size;

	kr = (*fintf)->WritePipe(fintf, pipe, buf, len);
	if (kr != noErr) {
		NSLog(@"Write error in bulkWrite.");
		return -1;
	}
	return 0;
}


- (SInt32) bulkRead:(UInt8)pipe buf:(UInt8*)buf size:(UInt32)size
{
	IOReturn			kr = noErr;
	UInt32				len = size;
	
	kr = (*fintf)->ReadPipe(fintf, pipe, buf, &len);
	if (kr != noErr) {
		NSLog(@"Read error in bulkRead.");
		return 0;
	}
	return len;
}

- (void) printErr:(IOReturn)kr
{
	printf("result:%08x\n", kr);
	
	IOReturn	err;
	err = err_get_system( kr );
	printf("err system:%02x\n", err);
	
	err = err_get_sub( kr );
	printf("err subsystem:%04x\n", err);
	
	err = err_get_code( kr );
	printf("err code:%04x\n", err);
}

@end

// --- デバイスの追加／削除

static void NewDeviceAdded(void *refCon, io_iterator_t iterator)
{
	Cusb					*cusb = (Cusb*)refCon;
    kern_return_t			kr;
    io_service_t			usbDevice;
    IOCFPlugInInterface 	**plugInInterface=NULL;
    IOUSBDeviceInterface 	**dev=NULL;
    HRESULT					res;
    SInt32					score;
	int						exclusiveErr = 0;

    while ( (usbDevice = IOIteratorNext(iterator)) )
    {
        kr = IOCreatePlugInInterfaceForService(usbDevice, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugInInterface, &score);
        kr = IOObjectRelease(usbDevice);
        if ((kIOReturnSuccess != kr) || !plugInInterface) {
            continue;
        }
            
        // デバイス・プラグインからデバイス・インターフェースを取得する。
        res = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID)&dev);
        (*plugInInterface)->Release(plugInInterface);
        if (res || !dev) {
			NSLog(@"NewDeviceAdded : QueryInterface error.");
            continue;
        }

        // デバイスをオープンする。
        do {
            kr = (*dev)->USBDeviceOpen(dev);
            if(kIOReturnExclusiveAccess == kr) {
				NSLog(@"NewDeviceAdded : USBDeviceOpen exclusiveErr.");
                exclusiveErr++;
                sleep(1);
            }
        } while((kIOReturnExclusiveAccess == kr) && (exclusiveErr < 5));	// 5回まで再試行する。
        if(kIOReturnSuccess != kr) {
			NSLog(@"NewDeviceAdded : USBDeviceOpen error.");
            (*dev)->Release(dev);
            continue;
        }

        kr = [cusb configureAnchorDevice:dev];
        if (kIOReturnSuccess != kr) {
			NSLog(@"NewDeviceAdded : configureAnchorDevice error.");
            (*dev)->USBDeviceClose(dev);
            (*dev)->Release(dev);
            continue;
        }

        kr = [cusb findInterfaces:dev];
        if (kIOReturnSuccess != kr) {
			NSLog(@"NewDeviceAdded : findInterfaces error.");
            (*dev)->USBDeviceClose(dev);
            (*dev)->Release(dev);
            continue;
        }

		[[NSNotificationCenter defaultCenter] postNotificationName:@"ConnectCUSB" object:nil];
    }
}

static void NewDeviceRemoved(void *refCon, io_iterator_t iterator)
{
//	Cusb			*cusb = (Cusb*)refCon;
    kern_return_t	result;
    io_service_t	obj;
    
    while((obj = IOIteratorNext(iterator))) {
        result = IOObjectRelease(obj);
		[[NSNotificationCenter defaultCenter] postNotificationName:@"DisconnectCUSB" object:nil];
    }
}
