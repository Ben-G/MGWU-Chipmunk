//
//  GameOverLayer.mm
//  PeevedPenguins
//
//  Created by Benjamin Encz on 5/1/13.
//
//

#import "GameOverLayer.h"
#import "kobold2d.h"
#import "StartMenuLayer.h"

@interface GameOverLayer()

@property (nonatomic, strong) CCMenuItemFont *startButton;

@end

@implementation GameOverLayer


-(id) init {
    
	if ((self = [super init])) {
        
        self.startButton = [[CCMenuItemFont alloc] initWithString:@"Back to Main Menu!" block:^(id sender) {
            [[CCDirector sharedDirector] replaceScene: [[StartMenuLayer alloc] init]];
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