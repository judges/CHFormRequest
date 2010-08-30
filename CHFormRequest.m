//
//  CHFormRequest.m
//  CHFormRequest
//
//  Created by Dave DeLong on 8/16/10.
//  Copyright 2010 Home. All rights reserved.
//

#import "CHFormRequest.h"

#pragma mark CHFormRequestFile

@interface CHFormRequestFile : NSObject {
	NSString * path;
}

+ (id) fileWithPath:(NSString *)aPath;
- (id) initWithPath:(NSString *)aPath;

- (NSString *) fileName;
- (NSString *) mimeType;
- (NSArray *) inputStreamsWithBoundary:(NSString *)boundary;

@end

@implementation CHFormRequestFile

+ (id) fileWithPath:(NSString *)aPath {
	return [[[self alloc] initWithPath:aPath] autorelease];
}

- (id) initWithPath:(NSString *)aPath {
	if ([[NSFileManager defaultManager] fileExistsAtPath:aPath] == NO) {
		[super dealloc];
		return nil;
	}
	
	if (self = [super init]) {
		path = [aPath copy];
	}
	return self;
}

- (void) dealloc {
	[path release];
	[super dealloc];
}

- (NSString *) fileName {
	return [path lastPathComponent];
}

- (NSString *) mimeType {
	CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)[path pathExtension], NULL);
	CFStringRef MIMEType = CFMakeCollectable(UTTypeCopyPreferredTagWithClass (UTI, kUTTagClassMIMEType));
	CFRelease(UTI);
	return [(NSString *)MIMEType autorelease];
}

- (NSArray *) inputStreamsWithBoundary:(NSString *)boundary {
	NSMutableArray * streams = [NSMutableArray array];
	
	NSString * header = [NSString stringWithFormat:@"--%@\r\nContent-Disposition: file; filename=\"%@\"\r\nContent-Type: application/octet-stream\r\nContent-Transfer-Encoding: binary\r\n\r\n", boundary, [self fileName]];
	NSInputStream * headerStream = [NSInputStream inputStreamWithData:[header dataUsingEncoding:NSUTF8StringEncoding]];
	[streams addObject:headerStream];
	
	NSInputStream * fileStream = [NSInputStream inputStreamWithFileAtPath:path];
	[streams addObject:fileStream];
	
	NSInputStream * footerStream = [NSInputStream inputStreamWithData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
	[streams addObject:footerStream];
	
	return streams;
}

@end

#pragma mark CHFormRequestInputStream

@interface CHFormRequestInputStream : NSInputStream <NSStreamDelegate>
{
	NSString * boundary;
	NSDictionary * fields;
	
	NSUInteger currentStreamIndex;
	NSInputStream * currentStream;
	
	NSMutableArray * inputStreams;
	NSStreamStatus status;
}

@property (nonatomic, retain) NSString * currentField;
@property NSUInteger currentStreamIndex;
@property (readonly) NSString * boundary;

- (id) initWithFields:(NSDictionary *)someFields;

@end

@implementation CHFormRequestInputStream
@synthesize currentField, currentStreamIndex, boundary;

- (id) initWithFields:(NSDictionary *)someFields {
	if (self = [super init]) {
		fields = [someFields retain];
		currentStreamIndex = 0;
		currentStream = nil;
		inputStreams = [[NSMutableArray alloc] init];
		status = NSStreamStatusNotOpen;
		
		CFUUIDRef uuid = CFUUIDCreate(NULL);
		boundary = (NSString *)CFMakeCollectable(CFUUIDCreateString(NULL, uuid));
		CFRelease(uuid);
	}
	return self;
}

- (void) dealloc {
	[boundary release];
	[fields release];
	[currentField release];
	[super dealloc];
}

- (NSString *) formEncodeString:(NSString *)value {
	NSMutableString * output = [NSMutableString string];
	const char * source = [value UTF8String];
	int sourceLen = strlen(source);
	for (int i = 0; i < sourceLen; ++i) {
		const unsigned char thisChar = (const unsigned char)source[i];
		if (thisChar == ' '){
			[output appendString:@"+"];
		} else if (thisChar == '.' || thisChar == '-' || thisChar == '_' || thisChar == '~' || 
				   (thisChar >= 'a' && thisChar <= 'z') ||
				   (thisChar >= 'A' && thisChar <= 'Z') ||
				   (thisChar >= '0' && thisChar <= '9')) {
			[output appendFormat:@"%c", thisChar];
		} else {
			[output appendFormat:@"%%%02X", thisChar];
		}
	}
	return output;
}

- (NSArray *) streamsForValue:(id)value inField:(NSString *)field boundary:(NSString *)boundaryString {
	if ([value isKindOfClass:[CHFormRequestFile class]]) {
		return [value inputStreamsWithBoundary:boundaryString];
	} else {
		NSArray * lines = [NSArray arrayWithObjects:
						   [NSString stringWithFormat:@"--%@", boundaryString],
						   [NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"", field],
						   @"Content-Type: application/x-www-form-urlencoded",
						   @"",
						   [self formEncodeString:value],
						   @"",
						   nil];
		NSString * fieldBody = [lines componentsJoinedByString:@"\r\n"];
		NSInputStream * fieldStream = [NSInputStream inputStreamWithData:[fieldBody dataUsingEncoding:NSUTF8StringEncoding]];
		return [NSArray arrayWithObject:fieldStream];
	}
}

- (NSArray *) streamsForValues:(NSArray *)values inField:(NSString *)field boundary:(NSString *)boundaryString {
	NSMutableArray * streams = [NSMutableArray array];
	if ([values count] == 1) {
		[streams addObjectsFromArray:[self streamsForValue:[values objectAtIndex:0] inField:field boundary:boundaryString]];
	} else {
		CFUUIDRef subUUID = CFUUIDCreate(NULL);
		NSString * subBoundary = (NSString *)CFMakeCollectable(CFUUIDCreateString(NULL, subUUID));
		CFRelease(subUUID);
		
		NSString * sectionHeader = [NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"%@\"\r\nContent-Type: multipart/mixed; boundary=%@\r\n\r\n", boundaryString, field, subBoundary];
		NSInputStream * sectionHeaderStream = [NSInputStream inputStreamWithData:[sectionHeader dataUsingEncoding:NSUTF8StringEncoding]];
		[streams addObject:sectionHeaderStream];
		
		for (id value in values) {
			[streams addObjectsFromArray:[self streamsForValue:value inField:field boundary:subBoundary]];
		}
		
		NSString * sectionFooter = [NSString stringWithFormat:@"--%@--\r\n", subBoundary];
		NSInputStream * sectionFooterStream = [NSInputStream inputStreamWithData:[sectionFooter dataUsingEncoding:NSUTF8StringEncoding]];
		[streams addObject:sectionFooterStream];
		
		[subBoundary release];
	}
	return streams;
}

- (void) buildStreamsIfNeeded {
	if ([inputStreams count] > 0) { return; }
	
	for (NSString * field in fields) {
		NSAutoreleasePool * fieldPool = [[NSAutoreleasePool alloc] init];
		
		NSArray * fieldValues = [fields objectForKey:field];
		NSArray * fieldStreams = [self streamsForValues:fieldValues inField:field boundary:boundary];
		[inputStreams addObjectsFromArray:fieldStreams];
		
		[fieldPool drain];
	}
	
	NSString * footerString = [NSString stringWithFormat:@"--%@--", boundary];
	NSInputStream * footerStream = [NSInputStream inputStreamWithData:[footerString dataUsingEncoding:NSUTF8StringEncoding]];
	[inputStreams addObject:footerStream];
}

- (void) open {
	[self buildStreamsIfNeeded];
	status = NSStreamStatusOpen;
	[inputStreams makeObjectsPerformSelector:@selector(open)];
	
	currentStreamIndex = 0;
	currentStream = nil;
	if ([inputStreams count] > 0) {
		currentStream = [inputStreams objectAtIndex:0];
	}
}

- (void) close {
	status = NSStreamStatusClosed;
	[inputStreams makeObjectsPerformSelector:@selector(close)];
}

- (id<NSStreamDelegate>) delegate {
	if (currentStreamIndex < [inputStreams count]) {
		return [(NSInputStream *)[inputStreams objectAtIndex:currentStreamIndex] delegate];
	}
	return self;
}

- (void) setDelegate:(id <NSStreamDelegate>)delegate {
	if (currentStreamIndex < [inputStreams count]) {
		[[inputStreams objectAtIndex:currentStreamIndex] setDelegate:delegate];
	} else {
		[super setDelegate:delegate];
	}
}

- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
	[(id<NSStreamDelegate>)currentStream stream:theStream handleEvent:streamEvent];
}

- (NSStreamStatus) streamStatus {
	return status;
}

- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len {
	if (currentStreamIndex >= [inputStreams count]) {
		currentStream = nil;
		status = NSStreamStatusAtEnd;
		return 0;	
	}
	
	status = NSStreamStatusReading;
	NSInteger result = [currentStream read:buffer maxLength:len];
	if (result == 0 && (currentStreamIndex < [inputStreams count] - 1)) {
		currentStreamIndex++;
		currentStream = [inputStreams objectAtIndex:currentStreamIndex];
		result = [self read:buffer maxLength:len];
	}
	
	if (result == 0) {
		currentStreamIndex = [inputStreams count];
		currentStream = nil;
	}
	
    return result;
	
}

- (BOOL)getBuffer:(uint8_t **)buffer length:(NSUInteger *)len {
	return NO;
}

- (BOOL)hasBytesAvailable {
	return (currentStream != nil);
}

- (NSData *) readData {
	uint8_t buffer[64 * 1024];
    NSMutableData * data = [NSMutableData data];
	
	[self open];
	
    int bytesRead;
    while ((bytesRead = [self read:buffer maxLength:sizeof(buffer)]) > 0) {
        [data appendBytes: buffer length: bytesRead];
    }
	
	[self close];
	return data;
}

- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode {
	NSLog(@"%@", NSStringFromSelector(_cmd));
}

- (void) _scheduleInCFRunLoop: (NSRunLoop *) inRunLoop forMode: (id) inMode
{
    // Safe to ignore this?
	NSLog(@"%@", NSStringFromSelector(_cmd));
}

- (void) _setCFClientFlags: (CFOptionFlags)inFlags
                  callback: (CFReadStreamClientCallBack) inCallback
                   context: (CFStreamClientContext) inContext
{
    // Safe to ignore this?
	NSLog(@"%@", NSStringFromSelector(_cmd));
}

@end



@implementation CHFormRequest

- (id)initWithURL:(NSURL *)theURL cachePolicy:(NSURLRequestCachePolicy)cachePolicy timeoutInterval:(NSTimeInterval)timeoutInterval {
	if (self = [super initWithURL:theURL cachePolicy:cachePolicy timeoutInterval:timeoutInterval]) {
		fields = [[NSMutableDictionary alloc] init];
		[super setHTTPMethod:@"POST"];
		
		CHFormRequestInputStream * inputStream = [[CHFormRequestInputStream alloc] initWithFields:fields];
		
		NSString * contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=\"%@\"", [inputStream boundary]];
		[self setValue:contentType forHTTPHeaderField:@"Content-Type"];
		
		[super setHTTPBodyStream:inputStream];
		[inputStream release];
	}
	return self;
}

- (void) setValue:(NSString *)value forFormField:(NSString *)field {
	if (value == nil) {
		[fields removeObjectForKey:field];
	} else {
		NSMutableArray * fieldValues = [NSMutableArray arrayWithObject:value];
		[fields setObject:fieldValues forKey:field];
	}
}

- (void) setFile:(NSString *)filePath forFormField:(NSString *)field {
	if (filePath == nil) {
		[fields removeObjectForKey:field];
	} else {
		CHFormRequestFile * file = [CHFormRequestFile fileWithPath:filePath];
		if (file != nil) {
			[fields setObject:[NSArray arrayWithObject:file] forKey:field];
		}
	}
}

- (void) setHTTPBody:(NSData *)data {
	NSLog(@"do not use -[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
}

- (void) setHTTPBodyStream:(NSInputStream *)stream {
	NSLog(@"do not use -[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
}

- (void)setHTTPMethod:(NSString *)method {
	NSLog(@"do not use -[%@ %@]", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
}

- (void) dumpStreamToBody {
	CHFormRequestInputStream * s = [[CHFormRequestInputStream alloc] initWithFields:fields];
	NSData * data = [s readData];
	[s release];
	
	[super setHTTPBody:data];
	[self setValue:[NSString stringWithFormat:@"%ld", [data length]] forHTTPHeaderField:@"Content-Length"];
}

@end
