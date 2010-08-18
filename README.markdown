#CHFormRequest

An `NSMutableURLRequest` subclass to make POSTing form data easy.

##Usage

	CHFormRequest * r = [[CHFormRequest alloc] initWithURL:[NSURL URLWithString:@"http://example.com/myForm.php"]];
	
	[r setValue:@"test" forFormField:@"field1"];	
	[r addValue:@"field2" forFormField:@"field2"];
	[r addFile:@"/Users/example/Desktop/myFile.txt" forFormField:@"file"];
	
	NSHTTPURLResponse * response = nil;
	NSError * error = nil;
	NSData * d = [NSURLConnection sendSynchronousRequest:r returningResponse:&response error:&error];
	[r release];

##Platforms

Tested on Mac OS X 10.5+, should work on iOS 3+

##Credits

Built by [Dave DeLong][1], with a heck of a lot of inspiration coming from [Dave Dribing][2], specifically [this file][3].

  [1]: http://davedelong.com
  [2]: http://www.dribin.org/dave/
  [3]: http://ddribin.googlecode.com/svn/trunk/nsurl/DDMultipartInputStream.m