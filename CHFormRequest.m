//
//  CHFormRequest.m
//  CHFormRequest
//
//  Created by Dave DeLong on 8/16/10.
//  Copyright 2010 Home. All rights reserved.
//

#import "CHFormRequest.h"

#define PRINT_STRING(s) printf("%s", [(s) UTF8String])

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
	PRINT_STRING(header);
	NSInputStream * headerStream = [NSInputStream inputStreamWithData:[header dataUsingEncoding:NSUTF8StringEncoding]];
	[streams addObject:headerStream];
	
	NSInputStream * fileStream = [NSInputStream inputStreamWithFileAtPath:path];
	PRINT_STRING(([NSString stringWithFormat:@"<file: %@>", path]));
	[streams addObject:fileStream];
	
	NSInputStream * footerStream = [NSInputStream inputStreamWithData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
	PRINT_STRING(@"\r\n");
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

- (NSArray *) streamsForValues:(NSArray *)values inField:(NSString *)field boundary:(NSString *)boundaryString {
	NSMutableArray * streams = [NSMutableArray array];
	if ([values count] == 1) {
		NSString * fieldBody = [NSString stringWithFormat:@"--%@\r\nContent-disposition: form-data; name=\"%@\"\r\n\r\n%@\r\n", boundaryString, field, [values objectAtIndex:0]];
		PRINT_STRING(fieldBody);
		NSInputStream * fieldStream = [NSInputStream inputStreamWithData:[fieldBody dataUsingEncoding:NSUTF8StringEncoding]];
		[streams addObject:fieldStream];	
	} else {
		CFUUIDRef subUUID = CFUUIDCreate(NULL);
		NSString * subBoundary = (NSString *)CFMakeCollectable(CFUUIDCreateString(NULL, subUUID));
		CFRelease(subUUID);
		
		NSString * sectionHeader = [NSString stringWithFormat:@"--%@\r\nContent-Disposition: form-data; name=\"%@\"\r\nContent-Type: multipart/mixed; boundary=%@\r\n\r\n", boundaryString, field, subBoundary];
		PRINT_STRING(sectionHeader);
		NSInputStream * sectionHeaderStream = [NSInputStream inputStreamWithData:[sectionHeader dataUsingEncoding:NSUTF8StringEncoding]];
		[streams addObject:sectionHeaderStream];
		
		for (id value in values) {
			NSArray * valueStreams = nil;
			if ([value isKindOfClass:[CHFormRequestFile class]]) {
				valueStreams = [value inputStreamsWithBoundary:subBoundary];
			} else {
				valueStreams = [self streamsForValues:[NSArray arrayWithObject:value] inField:field boundary:subBoundary];
			}
			[streams addObjectsFromArray:valueStreams];
		}
		
		NSString * sectionFooter = [NSString stringWithFormat:@"--%@--\r\n", subBoundary];
		PRINT_STRING(sectionFooter);
		NSInputStream * sectionFooterStream = [NSInputStream inputStreamWithData:[sectionFooter dataUsingEncoding:NSUTF8StringEncoding]];
		[streams addObject:sectionFooterStream];
		
		[subBoundary release];
	}
	return streams;
}

- (void) buildStreamsIfNeeded {
	if ([inputStreams count] > 0) { return; }
	
//	NSString * headerString = [NSString stringWithFormat:@"Content-Type: multipart/form-data; boundary=%@\r\n\r\n", boundary];
//	PRINT_STRING(headerString);
//	NSInputStream * headerStream = [NSInputStream inputStreamWithData:[headerString dataUsingEncoding:NSUTF8StringEncoding]];
//	[inputStreams addObject:headerStream];
//	
	for (NSString * field in fields) {
		NSAutoreleasePool * fieldPool = [[NSAutoreleasePool alloc] init];
		
		NSArray * fieldValues = [fields objectForKey:field];
		NSArray * fieldStreams = [self streamsForValues:fieldValues inField:field boundary:boundary];
		[inputStreams addObjectsFromArray:fieldStreams];
		
		[fieldPool drain];
	}
	
	NSString * footerString = [NSString stringWithFormat:@"--%@--\r\n\r\n", boundary];
	PRINT_STRING(footerString);
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

- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSString *)mode {
	NSLog(@"%@", NSStringFromSelector(_cmd));
}

- (void) _scheduleInCFRunLoop: (NSRunLoop *) inRunLoop forMode: (id) inMode
{
    // Safe to ignore this?
}

- (void) _setCFClientFlags: (CFOptionFlags)inFlags
                  callback: (CFReadStreamClientCallBack) inCallback
                   context: (CFStreamClientContext) inContext
{
    // Safe to ignore this?
}

@end



@implementation CHFormRequest

- (id)initWithURL:(NSURL *)theURL cachePolicy:(NSURLRequestCachePolicy)cachePolicy timeoutInterval:(NSTimeInterval)timeoutInterval {
	if (self = [super initWithURL:theURL cachePolicy:cachePolicy timeoutInterval:timeoutInterval]) {
		fields = [[NSMutableDictionary alloc] init];
		[super setHTTPMethod:@"POST"];
		
		CHFormRequestInputStream * inputStream = [[CHFormRequestInputStream alloc] initWithFields:fields];
		
		NSString * contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", [inputStream boundary]];
		[self setValue:contentType forHTTPHeaderField:@"Content-Type"];
		
		[super setHTTPBodyStream:inputStream];
		[inputStream release];
	}
	return self;
}

- (void) setValue:(NSString *)value forFormField:(NSString *)field {
	NSMutableArray * fieldValues = [NSMutableArray arrayWithObject:value];
	[fields setObject:fieldValues forKey:field];
}

- (void) addValue:(NSString *)value forFormField:(NSString *)field {
	NSMutableArray * fieldValues = [fields objectForKey:field];
	if (fieldValues == nil) {
		fieldValues = [NSMutableArray array];
		[fields setObject:fieldValues forKey:field];
	}
	[fieldValues addObject:value];
}

- (void) addFile:(NSString *)filePath forFormField:(NSString *)field {
	CHFormRequestFile * file = [CHFormRequestFile fileWithPath:filePath];
	if (file != nil) {
		NSMutableArray * fieldFiles = [fields objectForKey:field];
		if (fieldFiles == nil) {
			fieldFiles = [NSMutableArray array];
			[fields setObject:fieldFiles forKey:field];
		}
		[fieldFiles addObject:file];
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

- (void) dumpStream {
    uint8_t buffer[64 * 1024];
    NSMutableData * data = [NSMutableData data];
    
	CHFormRequestInputStream * s = [[CHFormRequestInputStream alloc] initWithFields:fields];
	[s open];
	
    int bytesRead;
    while ((bytesRead = [s read:buffer maxLength:sizeof(buffer)]) > 0) {
        [data appendBytes: buffer length: bytesRead];
    }
	
	[s close];
	[s release];
	
	NSLog(@"read: %@", [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]);
}

@end
