#CHFormRequest

An `NSMutableURLRequest` subclass to make POSTing form data easy.

##Usage

	CHFormRequest * r = [[CHFormRequest alloc] initWithURL:[NSURL URLWithString:@"http://example.com/myForm.php"]];
	
	[r setValue:@"test" forFormField:@"field1"];	
	[r setFile:@"/Users/example/Desktop/myFile.txt" forFormField:@"file"];
	
	NSHTTPURLResponse * response = nil;
	NSError * error = nil;
	NSData * d = [NSURLConnection sendSynchronousRequest:r returningResponse:&response error:&error];
	[r release];

##Platforms

Tested on Mac OS X 10.5+, should work on iOS 3+.  However, it has to use a private `NSInputStream` method in order to work properly.  If you're trying to get this on the app store, let me know and I'll see if I can work around it.

##Credits

Built by [Dave DeLong][1], with a heck of a lot of inspiration coming from [Dave Dribin][2], specifically [this file][3].

  [1]: http://davedelong.com
  [2]: http://www.dribin.org/dave/
  [3]: http://ddribin.googlecode.com/svn/trunk/nsurl/DDMultipartInputStream.m