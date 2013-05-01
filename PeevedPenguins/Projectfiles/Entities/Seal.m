//
//  Seal.m
//  PeevedPenguins
//
//  Created by Benjamin Encz on 5/1/13.
//
//

#import "Seal.h"

@implementation Seal


- (id)initWithSealImage {
    self = [super initWithFile:@"seal.png"];
    
    if (self) {
        self.health = 2;
    }
    
    return self;
}

@end
