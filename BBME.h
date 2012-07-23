//
//  BBME.h
//  bbme
//
//  Created by osoumen on 06/05/01.
//  Copyright 2006 osoumen. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Cusb.h"
#import "defines.h"

@interface BBME : NSObject {
	IBOutlet id			fScoreListWindow;
	IBOutlet id			fProgressWindow;
	IBOutlet id			fStartupWindow;
	IBOutlet id			fStatusMessage;
	IBOutlet id			fProgressBar;
	IBOutlet id			fListView;

	IBOutlet id				fSendBtn;
	IBOutlet NSTextField	*fSendMsg;
	IBOutlet id				fRecvMsg;

	Cusb		*fCusb;
	BOOL		fWorking;
	
	UInt8		buf[64], pb_temp;
}

- (void) awakeFromNib;
- (void) dealloc;

- (void) connectCUSB:(NSNotification*)note;
- (void) startConnection;
- (void) disconnectCUSB:(NSNotification*)note;

// --- コントロール関係のスレッド用操作メソッド
- (void) setStatusText:(NSString*)message;
- (void) startProgressBar:(NSNumber*)max;
- (void) incrementBarValue:(NSNumber*)value;
- (void) stopProgressBar;


- (void) send:(id)sender;

@end
