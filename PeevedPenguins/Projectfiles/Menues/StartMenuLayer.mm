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

@property (nonatomic, strong) CCMenuItemImage *startButton;
@property (nonatomic, strong) CCMenuItemFont *level2Button;

@end

@implementation StartMenuLayer
 

-(id) init {
    
	if ((self = [super init])) {
        CGSize winSize = [[CCDirector sharedDirector] winSize];
        CGPoint center = ccp(winSize.width/2, winSize.height/2);

        
        CCSprite *sprite = [CCSprite spriteWithFile:@"main_menu_background.png"];
        sprite.position = center;
        [self addChild:sprite z:-1];
        
        NSString *pathLevel1 = [[NSBundle mainBundle] pathForResource:@"Level1" ofType:@"plist"];
        NSDictionary *level1 = [NSDictionary dictionaryWithContentsOfFile:pathLevel1];
        
        NSString *pathLevel2 = [[NSBundle mainBundle] pathForResource:@"Level2" ofType:@"plist"];
        NSDictionary *level2 = [NSDictionary dictionaryWithContentsOfFile:pathLevel2];
        
        
        self.startButton = [CCMenuItemImage itemWithNormalImage:@"main_menu_button.png"
                                                  selectedImage: nil
                                                          block:^(id sender) {
                                                              CCScene *level1Scene = [GameLayer sceneWithLevelDescription:level1];
                                                              
                                                              [[CCDirector sharedDirector] replaceScene: [CCTransitionFlipAngular transitionWithDuration:0.5f scene:level1Scene]];
                                                          }];
        
        self.level2Button = [CCMenuItemFont itemWithString:@"Level 2" block:^(id sender) {
            CCScene *level2Scene = [GameLayer sceneWithLevelDescription:level2];
            
            [[CCDirector sharedDirector] replaceScene: [CCTransitionFlipAngular transitionWithDuration:0.5f scene:level2Scene]];
        }];
        
        self.level2Button.color = ccc3(0.5,0.5,0.5);
        
        NSNumber *userHighScore = [[NSUserDefaults standardUserDefaults] objectForKey:@"highScore"];
        if ([userHighScore intValue] >= 10) {
            self.level2Button.isEnabled = TRUE;
        } else {
            self.level2Button.isEnabled = FALSE;
        }
        
        CCMenu* menu = [CCMenu menuWithItems:self.startButton, self.level2Button, nil];
        [menu alignItemsVertically];
        menu.position = ccp(winSize.width/2, 100);
        
        [self addChild:menu];
        
        [self scheduleUpdate];
    }

    return self;
}

@end