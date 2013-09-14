//
//  BBME.m
//  bbme
//
//	十倍さんの作成した、BBME(Windows版)のソースコードを基に、osoumenがObjective-Cで全面的に書き直しました。
//	変更点としては、オリジナルの十倍さんのバージョンでは、操作を行う毎に、USBをリセットしていましたが、
//	このMacバージョンでは、接続時に一度だけ行うようにしています。
//	デバッグ用機能などの一部は未実装です
//
//  Modified by osoumen on Apr 29 2004.
//  Copyright of the Modification parts : Copyright (c) 2004, osoumen
//

#import "BBME.h"

#define GIMIC_USBVID 0x16c0
#define GIMIC_USBPID 0x05e5

@implementation BBME

- (void) awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(connectCUSB:)
												 name:@"ConnectCUSB"
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(disconnectCUSB:)
												 name:@"DisconnectCUSB"
											   object:nil];
}


- (void) dealloc
{
	if(fCusb != nil) {
		[fCusb release];
		fCusb = nil;
	}
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (void)windowWillClose:(NSNotification *)note
{
	[NSApp terminate:self];
}

- (void) applicationDidFinishLaunching:(NSNotification*)note
{
	fCusb = [[Cusb alloc] initVendor:GIMIC_USBVID product:GIMIC_USBPID];
}


//転送中のQuitを警告するメソッド
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)aApp
{
	if (fWorking == YES) {
		int	iRet = NSRunAlertPanel(NSLocalizedString(@"quit1",@""),
								   NSLocalizedString(@"quit2",@""),
								   NSLocalizedString(@"yes",@""),NSLocalizedString(@"no",@""),nil);
		if (iRet != NSAlertDefaultReturn) 
			return NSTerminateCancel;
		else
			return NSTerminateNow;
	}
	return NSTerminateNow;
}


- (void) applicationWillTerminate:(NSNotification*)note
{
	if(fCusb != nil) {
		[fCusb release];
		fCusb = nil;
	}
}

- (void) connectCUSB:(NSNotification*)note
{
	if ([fStartupWindow isVisible])
		[fStartupWindow orderOut:self];
	[self performSelectorOnMainThread:@selector(startConnection) withObject:nil waitUntilDone:NO];
}
- (void) startConnection
{
	[self stopProgressBar];
	[self setStatusText:@""];
	//接続されたらウィンドウを表示
	[fScoreListWindow makeKeyAndOrderFront:self];
	/*
	//ロムの初期化とエラーの出力
	if([self romInit] != YES){
		NSRunAlertPanel(NSLocalizedString(@"errorinit",@""),@"",@"OK",nil,nil);
	}
	[self romReadBytes:0 size:64];	//テスト読み込み
	[self updateList:self];
	 */
}


- (void) disconnectCUSB:(NSNotification*)note
{
	//接続を解除したらウィンドウを隠す
	[fScoreListWindow orderOut:self];
	[fStartupWindow makeKeyAndOrderFront:self];
}

// --- スレッドから呼ばれて、メインスレッド内で処理される処理

- (void) setStatusText:(NSString*)message
{
	[fStatusMessage setStringValue:message];
}

- (void) startProgressBar:(NSNumber*)max
{
	fWorking = YES;
	//最大値に０を指定した場合、不定値バーになる
	double	value = [max doubleValue];
	[fProgressBar setDoubleValue:0.0];
	[fProgressBar setMaxValue:value];
	if (value > 0.0) {
		[fProgressBar setIndeterminate:NO];
	}
	else {
		[fProgressBar setIndeterminate:YES];
		[fProgressBar startAnimation:self];
	}
	[fProgressWindow makeKeyAndOrderFront:self];
	[fListView setEnabled:NO];
//	[fReloadButton setEnabled:NO];
//	[fTransferButton setEnabled:NO];
}

- (void) incrementBarValue:(NSNumber*)value
{
	[fProgressBar incrementBy:[value doubleValue]];
}

- (void) stopProgressBar
{
//	[fReloadButton setEnabled:YES];
	[fListView setEnabled:YES];
	[fProgressWindow orderOut:self];
	if ([fProgressBar isIndeterminate] == YES)
		[fProgressBar stopAnimation:self];
	fWorking = NO;
	[NSApp requestUserAttention:NSInformationalRequest];
}

// --- メニューアイテムの使用可否の処理

- (BOOL) validateMenuItem:(NSMenuItem*)anItem
{
//	SEL menuAction = [anItem action]; // メニューアイテムのアクションを取得

	return NO;
}

- (void) send:(id)sender
{
	int i;
	char	textbuf[128];
	NSString *text = [fSendMsg stringValue];
	if ( [text getCString:textbuf maxLength:128 encoding:NSASCIIStringEncoding] ) {
		int		txt_count = 0;
		int		buf_count = 0;
		while ( textbuf[txt_count] ) {
			if ( textbuf[txt_count] >= '0' && textbuf[txt_count] <= '9' ) {
				buf[buf_count] = (textbuf[txt_count] - '0') << 4;
			}
			if ( textbuf[txt_count] >= 'a' && textbuf[txt_count] <= 'f' ) {
				buf[buf_count] = (textbuf[txt_count] - 'a' + 10) << 4;
			}
			if ( textbuf[txt_count] >= 'A' && textbuf[txt_count] <= 'F' ) {
				buf[buf_count] = (textbuf[txt_count] - 'A' + 10) << 4;
			}
			txt_count++;
			
			if ( textbuf[txt_count] == 0 ) {
				break;
			}
			
			if ( textbuf[txt_count] >= '0' && textbuf[txt_count] <= '9' ) {
				buf[buf_count] += (textbuf[txt_count] - '0');
			}
			if ( textbuf[txt_count] >= 'a' && textbuf[txt_count] <= 'f' ) {
				buf[buf_count] += (textbuf[txt_count] - 'a' + 10);
			}
			if ( textbuf[txt_count] >= 'A' && textbuf[txt_count] <= 'F' ) {
				buf[buf_count] += (textbuf[txt_count] - 'A' + 10);
			}
			txt_count++;
			buf_count++;
		}
		
		[fCusb bulkWrite:RGIO_CPIPE buf:buf size:buf_count];
		UInt32			actual;
		
		actual = [fCusb bulkRead:RGIO_RPIPE buf:buf size:64];
		
		printf( "actusl = %d\n", actual );
		for ( i=0; i<actual; i++ ) {
			printf( "%02x ", buf[i] );
		}
		buf[actual] = 0;
		printf("\n'%s'\n", buf);
		
		[fSendMsg setStringValue:@""];
	}
}

@end
