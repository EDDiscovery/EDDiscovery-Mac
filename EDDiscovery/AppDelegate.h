//
//  AppDelegate.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 15/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Jump;

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property(nonatomic, strong) Jump *selectedJump;

@end

