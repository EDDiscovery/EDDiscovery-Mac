//
//  NSURLConnection+Progress.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 12/05/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//
//

#import <Foundation/Foundation.h>

@interface NSURLConnection (Progress)

typedef void (^ProgressBlock)(long long downloaded, long long total);
typedef void (^CompletionBlock)(NSHTTPURLResponse *response, NSData *data, NSError *error);

+ (void)sendAsynchronousRequest:(NSURLRequest *)request
                progressHandler:(ProgressBlock)progressHandler
              completionHandler:(CompletionBlock)completionHandler;

@end
