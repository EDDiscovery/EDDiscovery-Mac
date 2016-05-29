//
//  NSURLConnection+Progress.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 12/05/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//
//

#import <objc/runtime.h>

#import "NSURLConnection+Progress.h"

#define MAX_CONCURRENT_CONNECTIONS 8

@interface NSURLConnection () <NSURLConnectionDelegate>
@end

@implementation NSURLConnection (Progress)

static NSOperationQueue *queue;
static dispatch_once_t   onceToken;


static char progressHandlerKey;
static char completionHandlerKey;
static char dataKey;
static char responseKey;
static char finishedKey;

+ (void)sendAsynchronousRequest:(NSURLRequest *)request
                progressHandler:(ProgressBlock)progressHandler
              completionHandler:(CompletionBlock)completionHandler {
  
  dispatch_once(&onceToken, ^{
    queue = [[NSOperationQueue alloc] init];
    
    queue.maxConcurrentOperationCount = MAX_CONCURRENT_CONNECTIONS;
  });

  [queue addOperationWithBlock:^{
    NSRunLoop       *runLoop  = [NSRunLoop currentRunLoop];
    NSMutableData   *data     = [NSMutableData data];
    NSURLConnection *conn     = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    BOOL             finished = NO;
    
    objc_setAssociatedObject (conn, &progressHandlerKey,    progressHandler,    OBJC_ASSOCIATION_COPY);
    objc_setAssociatedObject (conn, &completionHandlerKey,  completionHandler,  OBJC_ASSOCIATION_COPY);
    objc_setAssociatedObject (conn, &dataKey,               data,               OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject (conn, &finishedKey,           @(finished),        OBJC_ASSOCIATION_RETAIN);
    
    [conn scheduleInRunLoop:runLoop forMode:NSRunLoopCommonModes];
    [conn start];
    
    while (!finished) {
      [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
      
      finished = [(NSNumber *)objc_getAssociatedObject(conn, &finishedKey) boolValue];
    }
  }];
}

#pragma mark - NSURLConnection management

+ (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
  NSHTTPURLResponse *response        = objc_getAssociatedObject(connection, &responseKey);
  CompletionBlock    completionBlock = objc_getAssociatedObject(connection, &completionHandlerKey);

  objc_setAssociatedObject (connection, &finishedKey, @YES, OBJC_ASSOCIATION_RETAIN);
  
  dispatch_async(dispatch_get_main_queue(), ^{
    completionBlock(response, nil, error);
  });
}

+ (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
  objc_setAssociatedObject (connection, &responseKey, response, OBJC_ASSOCIATION_RETAIN);
}

+ (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
  NSHTTPURLResponse *response      = objc_getAssociatedObject(connection, &responseKey);
  NSMutableData     *connData      = objc_getAssociatedObject(connection, &dataKey);
  ProgressBlock      progressBlock = objc_getAssociatedObject(connection, &progressHandlerKey);
  
  [connData appendData:data];
  
  if (progressBlock != nil) {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (response.expectedContentLength == NSURLResponseUnknownLength) {
        progressBlock(connData.length, connData.length);
      }
      else {
        progressBlock(connData.length, response.expectedContentLength);
      }
    });
  }
}

+ (void)connectionDidFinishLoading:(NSURLConnection *)connection {
  NSHTTPURLResponse *response        = objc_getAssociatedObject(connection, &responseKey);
  NSMutableData     *connData        = objc_getAssociatedObject(connection, &dataKey);
  CompletionBlock    completionBlock = objc_getAssociatedObject(connection, &completionHandlerKey);
  
  objc_setAssociatedObject (connection, &finishedKey, @YES, OBJC_ASSOCIATION_RETAIN);
  
  dispatch_async(dispatch_get_main_queue(), ^{
    completionBlock(response, connData, nil);
  });
}

@end
