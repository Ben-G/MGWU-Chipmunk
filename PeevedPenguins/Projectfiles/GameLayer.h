/*
 * Kobold2D™ --- http://www.kobold2d.org
 *
 * Copyright (c) 2010-2011 Steffen Itterheim. 
 * Released under MIT License in Germany (LICENSE-Kobold2D.txt).
 */

#import "cocos2d.h"
#import "Box2D.h"
#import "ContactListener.h"
enum
{
	kTagBatchNode,
};

@interface GameLayer : CCLayer
{
	b2World* world;
    int currentBullet;
    NSMutableArray *bullets;
    ContactListener *contactListener;
    b2Body *screenBorderBody;
    b2Fixture *armFixture; //will store the shape and density information of the catapult arm
    b2Body *armBody;  //will store the position and type of the catapult arm
}

-(id)initWithLevelDescription:(NSDictionary*)levelDescription;

+(id) sceneWithLevelDescription:(NSDictionary*)levelDescription;
- (void)createBullets;

@end
