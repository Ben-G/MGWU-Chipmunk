/*
 * Kobold2D™ --- http://www.kobold2d.org
 *
 * Copyright (c) 2010-2011 Steffen Itterheim. 
 * Released under MIT License in Germany (LICENSE-Kobold2D.txt).
 */

#import "GameLayer.h"
#import "SimpleAudioEngine.h"
#import "GameOverLayer.h"
#import "Seal.h"
#import "chipmunk.h"

const float PTM_RATIO = 32.0f;
#define FLOOR_HEIGHT    50.0f
#define SPEED_FACTOR     1.0f
#define MAX_MUNITION        2

CCSprite *projectile;
CCSprite *block;
CGRect firstrect;
CGRect secondrect;
NSMutableArray *blocks = [[NSMutableArray alloc] init];
cpSpace *space;



@interface GameLayer ()
-(void) enableBox2dDebugDrawing;
-(void) addSomeJoinedBodies:(CGPoint)pos;
-(void) addNewSpriteAt:(CGPoint)p;
-(b2Vec2) toMeters:(CGPoint)point;
-(CGPoint) toPixels:(b2Vec2)vec;
- (BOOL)gameOver;

@property (nonatomic, strong) CCAction *taunt;
@property (nonatomic, strong) NSMutableArray *tauntingFrames;
@property (nonatomic, assign) int usedMunition;

@end

@implementation GameLayer

-(void) dealloc
{
	delete world;
    self.taunt = nil;
    self.tauntingFrames = nil;
    
#ifndef KK_ARC_ENABLED
	[super dealloc];
#endif
}


-(id)initWithLevelDescription:(NSDictionary*)levelDescription
{
	if ((self = [super init]))
	{
		CCLOG(@"%@ init", NSStringFromClass([self class]));
        
        // setup chipmunk space
        [self createChipmunkSpace];
        
        bullets = [[NSMutableArray alloc] init];
        self.usedMunition = 0;
        
        // Construct a world object, which will hold and simulate the rigid bodies.
		b2Vec2 gravity = b2Vec2(0.0f, -10.0f);
		world = new b2World(gravity);
		world->SetAllowSleeping(YES);
		//world->SetContinuousPhysics(YES);
        
        //create an object that will check for collisions
		contactListener = new ContactListener();
		world->SetContactListener(contactListener);
        
		glClearColor(0.1f, 0.0f, 0.2f, 1.0f);
        
        CGSize screenSize = [CCDirector sharedDirector].winSize;

        
        b2Vec2 lowerLeftCorner =b2Vec2(0,0);
		b2Vec2 lowerRightCorner = b2Vec2(screenSize.width/PTM_RATIO,0);
		b2Vec2 upperLeftCorner = b2Vec2(0,screenSize.height/PTM_RATIO);
		b2Vec2 upperRightCorner = b2Vec2(screenSize.width/PTM_RATIO,screenSize.height/PTM_RATIO);
		
		// Define the static container body, which will provide the collisions at screen borders.
		b2BodyDef screenBorderDef;
		screenBorderDef.position.Set(0, 0);
        screenBorderBody = world->CreateBody(&screenBorderDef);
		b2EdgeShape screenBorderShape;
        
        screenBorderShape.Set(lowerLeftCorner, lowerRightCorner);
        screenBorderBody->CreateFixture(&screenBorderShape, 0);
        
        screenBorderShape.Set(lowerRightCorner, upperRightCorner);
        screenBorderBody->CreateFixture(&screenBorderShape, 0);
        
        screenBorderShape.Set(upperRightCorner, upperLeftCorner);
        screenBorderBody->CreateFixture(&screenBorderShape, 0);
        
        screenBorderShape.Set(upperLeftCorner, lowerLeftCorner);
        screenBorderBody->CreateFixture(&screenBorderShape, 0);
        
        
        //Add all the sprites to the game, including blocks and the catapult. It's tedious...
        //See the storing game data tutorial to learn how to abstract all of this out to a plist file
        
        
        NSArray *blockDescriptions = [levelDescription objectForKey:@"blocks"];
        
        for (NSDictionary *block in blockDescriptions) {
            NSString *fileName = [block objectForKey:@"spriteName"];
            fileName = [fileName stringByAppendingString:@".png"];
            float x = [[block objectForKey:@"x"] intValue];
            float y = [[block objectForKey:@"y"] intValue];
            
            CCSprite *sprite = [CCSprite spriteWithFile:fileName];
            sprite.anchorPoint = CGPointZero;
            sprite.position = ccp(x,y);
            [self addChild:sprite z:7];
        }
        
        CCSprite *sprite = [CCSprite spriteWithFile:@"background.png"];
        sprite.anchorPoint = CGPointZero;
        [self addChild:sprite z:-1];
        
        sprite = [CCSprite spriteWithFile:@"catapult.png"];
        sprite.anchorPoint = CGPointZero;
        sprite.position = CGPointMake(135.0f, FLOOR_HEIGHT);
        [self addChild:sprite z:0];
        
        
        //Load the plist which tells Kobold2D how to properly parse your spritesheet. If on a retina device Kobold2D will automatically use bearframes-hd.plist
        
        [[CCSpriteFrameCache sharedSpriteFrameCache] addSpriteFramesWithFile: @"bearframes.plist"];
        
        //Load in the spritesheet, if retina Kobold2D will automatically use bearframes-hd.png
        
        // *****+ BATCH NODE CURRENTLY NOT IN USE ********
        //CCSpriteBatchNode *spriteSheet = [CCSpriteBatchNode batchNodeWithFile:@"bearframes.png"];
        //[self addChild:spriteSheet];
        
        //Define the frames based on the plist - note that for this to work, the original files must be in the format bear1, bear2, bear3 etc...
        
        //When it comes time to get art for your own original game, makegameswith.us will give you spritesheets that follow this convention, <spritename>1 <spritename>2 <spritename>3 etc...
        
        self.tauntingFrames = [NSMutableArray array];
        
        for(int i = 1; i <= 7; ++i)
        {
            [self.tauntingFrames addObject:
             [[CCSpriteFrameCache sharedSpriteFrameCache] spriteFrameByName: [NSString stringWithFormat:@"bear%d.png", i]]];
        }
        
        //Initialize the bear with the first frame you loaded from your spritesheet, bear1
        
        sprite = [CCSprite spriteWithSpriteFrameName:@"bear1.png"];
        
        sprite.anchorPoint = CGPointZero;
        sprite.position = CGPointMake(50.0f, FLOOR_HEIGHT);
        
        //Create an animation from the set of frames you created earlier
        
        CCAnimation *taunting = [CCAnimation animationWithSpriteFrames: self.tauntingFrames delay:0.5f];
        
        //Create an action with the animation that can then be assigned to a sprite
        
        self.taunt = [CCRepeatForever actionWithAction: [CCAnimate actionWithAnimation:taunting restoreOriginalFrame:NO]];
        
        //tell the bear to run the taunting action
        [sprite runAction:self.taunt];
        
        [self addChild:sprite z:0];
            
        sprite = [CCSprite spriteWithFile:@"ground.png"];
        sprite.anchorPoint = CGPointZero;
        [self addChild:sprite z:10];
        
                
        Seal *seal = [[Seal alloc] initWithSealImage];
        seal.position = CGPointMake(680.0f, FLOOR_HEIGHT + 72.0f);
        [blocks addObject:seal];
        [self addChild:seal z:7];
        
        
        Seal *seal2 = [[Seal alloc] initWithSealImage];
        seal.position = CGPointMake(740.0f, FLOOR_HEIGHT + 72.0f);
        [blocks addObject:seal2];
        [self addChild:seal2 z:7];
        
        
        CCSprite *arm = [CCSprite spriteWithFile:@"catapultarm.png"];
        arm.position = CGPointMake(230.0f, FLOOR_HEIGHT+130.0f);
        [self addChild:arm z:-1];
		
        [[SimpleAudioEngine sharedEngine] preloadEffect:@"explo2.wav"];
        
        //schedules a call to the update method every frame
		[self scheduleUpdate];
	}
    
	return self;
}


+(id) sceneWithLevelDescription:(NSDictionary*)levelDescription
{
    CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	GameLayer *layer = [[GameLayer alloc] initWithLevelDescription:levelDescription];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

- (void)createChipmunkSpace {
    // create chipmunkt space and store reference
    space = cpSpaceNew();
    // setup gravity
    space->gravity = ccp(0, -750);
    // following lines unavailable in Chipmunk 6 
    /*cpSpaceResizeStaticHash(space, 400, 200);
    cpSpaceResizeActiveHash(space, 200, 200);*/
}

- (void)createGround {
    /*
     We’re going to make the ground as a line from the lower left of the screen to the lower right of the screen, so this gets the coordinates of these for future reference.
     */
    CGSize winSize = [CCDirector sharedDirector].winSize;
    CGPoint lowerLeft = ccp(0, FLOOR_HEIGHT);
    CGPoint lowerRight = ccp(2 * winSize.width, FLOOR_HEIGHT);
    
    /*
     Creates a new Chipmunk body – a static body, because it never moves. Usually you have to add the body to the scene, but you don’t have to for static bodies. 
     */
    cpBody *groundBody = cpBodyNewStatic();
    
    /*
     Creates a new segment shape and associates it to the body just created.
     */
    //TODO: Benji: Check how radius is used
    float radius = 10.0;
    cpShape *groundShape = cpSegmentShapeNew(groundBody, lowerLeft, lowerRight, radius);
    
    /*
     Sets the elasticity to be somewhat bouncy, and the friction to be not very slippery.
     */
    groundShape->e = 0.5; // elasticity
    groundShape->u = 1.0; // friction
    
    /*
     Adds the shape to the Chipmunk space.
     */
    cpSpaceAddShape(space, groundShape);
}

//indicates whether or not the game is over
- (BOOL)gameOver {
    // game is over
    if ( (self.usedMunition == MAX_MUNITION) && ([bullets count] == 0)) {
        [[NSUserDefaults standardUserDefaults] setObject:@10 forKey:@"highScore"];
        return TRUE;
    } else {
        return FALSE;
    }
    
    return FALSE;
}

//Create the bullets, add them to the list of bullets so they can be referred to later
- (void)createBullets
{
    CCSprite *bullet = [CCSprite spriteWithFile:@"flyingpenguin.png"];
    bullet.position = CGPointMake(250.0f, FLOOR_HEIGHT+190.0f);
    [self addChild:bullet z:9];
    [bullets addObject:bullet];
}

//Check through all the bullets and blocks and see if they intersect
-(void) detectCollisions
{
    for(int i = 0; i < [bullets count]; i++)
    {
        for(int j = 0; j < [blocks count]; j++)
        {
            if([bullets count]>0)
            {
                NSInteger first = i;
                NSInteger second = j;
                block = [blocks objectAtIndex:second];
                projectile = [bullets objectAtIndex:first];
                
                firstrect = [projectile textureRect];
                secondrect = [block textureRect];
                //check if their x coordinates match
                if(projectile.position.x == block.position.x)
                {
                    //check if their y coordinates are within the height of the block
                    if(projectile.position.y < (block.position.y + 23.0f) && projectile.position.y > block.position.y - 23.0f)
                    {
                       
                        
                        if([block isKindOfClass:[Seal class]]) {
                            if (((Seal*)block).health==1)
                            {
                                [self removeChild:block cleanup:YES];
                                [self removeChild:projectile cleanup:YES];
                                [blocks removeObjectAtIndex:second];
                                [bullets removeObjectAtIndex:first];
                            }
                            else
                            {
                                ((Seal*)block).health--;
                                [self removeChild:projectile cleanup:YES];
                                [bullets removeObjectAtIndex:first];
                            }
                        } else {
                            [self removeChild:block cleanup:YES];
                            [self removeChild:projectile cleanup:YES];
                            [blocks removeObjectAtIndex:second];
                            [bullets removeObjectAtIndex:first];
                            [[SimpleAudioEngine sharedEngine] playEffect:@"explo2.wav"];
                        }
                    }
                }
            }
            
        }
        
    }
}


-(void) update:(ccTime)delta
{
    if ([self gameOver]) {
        [self unscheduleUpdate];
        
        [[CCDirector sharedDirector] replaceScene: [CCTransitionFlipAngular transitionWithDuration:0.5f scene:[[GameOverLayer alloc] init]]];
    }
    
    //Check for inputs and create a bullet if there is a tap and munition is not used up yet
    KKInput* input = [KKInput sharedInput];
    if(input.anyTouchEndedThisFrame && (self.usedMunition < MAX_MUNITION))
    {
        [self createBullets];
        self.usedMunition++;
    }
    //Move the projectiles to the right and down
    for(int i = 0; i < [bullets count]; i++)
    {
        NSInteger j = i;
        projectile = [bullets objectAtIndex:j];
        projectile.position = ccp(projectile.position.x + (1.0f*SPEED_FACTOR),projectile.position.y - (0.25f*SPEED_FACTOR));
    }
    //Move the screen if the bullets move too far right
    if([bullets count] > 0)
    {
        projectile = [bullets objectAtIndex:0];
        if(projectile.position.x > 320 && self.position.x > -480)
        {
            self.position = ccp(self.position.x - 1, self.position.y);
        }
    }
    //If there are bullets and blocks in existence, check if they are colliding
    if([bullets count] > 0 && [blocks count] > 0)
    {
        [self detectCollisions];
    }
}

// convenience method to convert a b2Vec2 to a CGPoint
-(CGPoint) toPixels:(b2Vec2)vec
{
	return ccpMult(CGPointMake(vec.x, vec.y), PTM_RATIO);
}


@end
