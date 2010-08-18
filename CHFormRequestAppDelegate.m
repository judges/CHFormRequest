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
	
	CHFormRequest * r = [[CHFormRequest alloc] initWithURL:[NSURL URLWithString:@"http://davedelong.com/curl/post.php"]];
	
	[r setValue:@"test" forFormField:@"field1"];
//	[r addValue:@"test1" forFormField:@"field1"];
	
	[r addValue:@"field2" forFormField:@"field2"];
	
//	[r dumpStream];
	
	NSHTTPURLResponse * response = nil;
	NSError * error = nil;
	NSData * d = [NSURLConnection sendSynchronousRequest:r returningResponse:&response error:&error];
	
	NSLog(@"response: %@", response);
	NSLog(@"error: %@", error);
	
	NSLog(@"data: %@", [[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] autorelease]);
	
	[r release];
}

@end
