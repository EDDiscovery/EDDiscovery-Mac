//
//  SystemData.m
//  EDDiscovery
//
//  Created by thorin on 03/05/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "SystemData.h"

#import "System.h"

@implementation SystemData

+ (double)distance:(System *)s1 :(System *)s2 {
  if (s1 == nil || s2== nil)
    return -1;
  
  //return Math.Sqrt(Math.Pow(s1.x - s2.x, 2) + Math.Pow(s1.y - s2.y, 2) + Math.Pow(s1.z - s2.z, 2));
  return sqrt((s1.x - s2.x) * (s1.x - s2.x) + (s1.y - s2.y) * (s1.y - s2.y) + (s1.z - s2.z) * (s1.z - s2.z));
}

+ (double)distanceX2:(System *)s1 :(System *)s2 {
  if (s1 == nil || s2 == nil)
    return -1;
  
  //return Math.Sqrt(Math.Pow(s1.x - s2.x, 2) + Math.Pow(s1.y - s2.y, 2) + Math.Pow(s1.z - s2.z, 2));
  return ((s1.x - s2.x) * (s1.x - s2.x) + (s1.y - s2.y) * (s1.y - s2.y) + (s1.z - s2.z) * (s1.z - s2.z));
}

@end
