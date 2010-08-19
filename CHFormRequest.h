//
//  CHFormRequest.h
//  CHFormRequest
//
//  Created by Dave DeLong on 8/16/10.
//  Copyright 2010 Home. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface CHFormRequest : NSMutableURLRequest {
	NSMutableDictionary * fields;
}

- (void) setValue:(NSString *)value forFormField:(NSString *)field;
//- (void) addValue:(NSString *)value forFormField:(NSString *)field;

- (void) setFile:(NSString *)filePath forFormField:(NSString *)field;

- (void) dumpStreamToBody;

@end
