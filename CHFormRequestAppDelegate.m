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
	
	[r dumpStreamToBody];
	
	NSHTTPURLResponse * response = nil;
	NSError * error = nil;
	NSData * d = [NSURLConnection sendSynchronousRequest:r returningResponse:&response error:&error];
	
	NSLog(@"response: %@", response);
	NSLog(@"error: %@, %@", error, [error userInfo]);
//	NSLog(@"%@, %@", [[error userInfo] objectForKey:NSUnderlyingErrorKey], [[[error userInfo] objectForKey:NSUnderlyingErrorKey] userInfo]);
	
	NSLog(@"data: %@", [[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] autorelease]);
	
	[r release];
}

@end
