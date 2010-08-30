//
//  CHFormRequestAppDelegate.m
//  CHFormRequest
//
//  Created by Dave DeLong on 8/16/10.
//  Copyright 2010 Home. All rights reserved.
//

#import "CHFormRequestAppDelegate.h"
#import "CHFormRequest.h"

@implementation CHFormRequestAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application 
	
	CHFormRequest * r = [[CHFormRequest alloc] initWithURL:[NSURL URLWithString:@"http://bing.com/search"]];
	[r setURL:[NSURL URLWithString:@"http://localhost/post.php"]];
	
	[r setValue:@"HTTP Post Request" forFormField:@"q"];
	[r setValue:@"HTTP Post Request1" forFormField:@"q1"];
	[r setValue:@"HTTP Post Request2" forFormField:@"q2"];
	[r setValue:@"HTTP Post Request3" forFormField:@"q3"];
//	[r setFile:@"/Users/dave/Desktop/license.jpg" forFormField:@"file"];
	[r setFile:@"/Library/User Pictures/Fun/Beach Ball.tif" forFormField:@"file"];
//	[r setFile:@"/Library/User Pictures/Fun/Caduceus.tif" forFormField:@"file"];
	
//	[r dumpStreamToBody];
	
	NSHTTPURLResponse * response = nil;
	NSError * error = nil;
	NSData * d = [NSURLConnection sendSynchronousRequest:r returningResponse:&response error:&error];
	
	NSLog(@"response: %@", response);
	NSLog(@"error: %@, %@", error, [error userInfo]);
	
	NSLog(@"data: %@", [[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] autorelease]);
	
	[r release];
}

@end
