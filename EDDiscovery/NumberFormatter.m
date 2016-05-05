//
//  NumberFormatter.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 05/05/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "NumberFormatter.h"

@implementation NumberFormatter

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString  **)error {
  BOOL result = [super getObjectValue:obj forString:string errorDescription:error];
  
  if (result == NO) {
    NSString *separator = self.decimalSeparator;
    
    if ([separator isEqualToString:@"."] == NO) {
      self.decimalSeparator = @".";
      
      result = [super getObjectValue:obj forString:string errorDescription:error];
      
      self.decimalSeparator = separator;
    }
  }
  
  return result;
}

@end
