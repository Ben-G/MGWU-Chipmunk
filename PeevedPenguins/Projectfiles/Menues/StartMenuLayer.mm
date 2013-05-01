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
        CGSize winSize = [[CCDirector sharedDirector] winSize];
        CGPoint center = ccp(winSize.width/2, winSize.height/2);

        
        CCSprite *sprite = [CCSprite spriteWithFile:@"main_menu_background.png"];
        sprite.position = center;
        [self addChild:sprite z:-1];
        
        self.startButton = [CCMenuItemImage itemWithNormalImage:@"main_menu_button.png"
                                                  selectedImage: nil
                                                          block:^(id sender) {
                                                              [[CCDirector sharedDirector] replaceScene: [CCTransitionFlipAngular transitionWithDuration:0.5f scene:[GameLayer scene]]];
                                                          }];
        
        CCMenu* menu = [CCMenu menuWithItems:self.startButton, nil];
        menu.position = ccp(winSize.width/2, 100);
        
        [self addChild:menu];
        
        [self scheduleUpdate];
    }

    return self;
}

@end