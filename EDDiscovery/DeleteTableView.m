//
//  DeleteTableView.m
//  EDDiscovery
//
//  Created by thorin on 25/05/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "DeleteTableView.h"

@implementation DeleteTableView

- (void)keyDown:(NSEvent *)theEvent {
  unichar key = [[theEvent charactersIgnoringModifiers] characterAtIndex:0];
  
  if (key == NSDeleteCharacter) {
    [self deleteItem];
    
    return;
  }
  
  [super keyDown:theEvent];
}

- (void)deleteItem {
  if (self.numberOfSelectedRows == 0) {
    return;
  }
  
  SEL selector = sel_registerName("tableView:deleteRow:");
  
  if ([self.delegate respondsToSelector:selector]) {
    NSTableView       *selTableView = self;
    NSInteger          selRow       = self.selectedRow;
    NSMethodSignature *signature    = [[self.delegate class] instanceMethodSignatureForSelector: selector];
    NSInvocation      *invocation   = [NSInvocation invocationWithMethodSignature: signature];
    
    [invocation setTarget:self.delegate];
    [invocation setSelector:selector];
    [invocation setArgument:&selTableView atIndex:2];
    [invocation setArgument:&selRow       atIndex:3];
    
    [invocation invoke];
  }
}

@end
