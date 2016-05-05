//
//  SuggestedReferences.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 03/05/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>

@class System;
@class ReferenceSystem;

@interface SuggestedReferences : NSObject

- (id)initWithLastKnownPosition:(System *)system;
- (ReferenceSystem *)getCandidate;
- (void)addReferenceStar:(System *)sys;

@end
