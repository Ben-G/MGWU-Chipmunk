//
//  StartMenueLayer.mm
//  PeevedPenguins
//
//  Created by Benjamin Encz on 4/28/13.
//
//

#import "kobold2d.h"
#import "StartMenuLayer.h"
#import "GameLayer.h"

@interface StartMenuLayer()

@property (nonatomic, strong) CCMenuItemFont *startButton;

@end

@implementation StartMenuLayer
 

-(id) init {
    
	if ((self = [super init])) {
        
        self.startButton = [[CCMenuItemFont alloc] initWithString:@"Start" block:^(id sender) {
            [[CCDirector sharedDirector] replaceScene: [CCTransitionFlipAngular transitionWithDuration:0.5f scene:[GameLayer scene]]];
        }];
        self.startButton.fontSize = 12;
        
        CCMenu* menu = [CCMenu menuWithItems:self.startButton, nil];
        menu.position = ccp(100, 100);
        [menu alignItemsVertically];
        [self addChild:menu];
        
        [self scheduleUpdate];
    }

    return self;
}

@end