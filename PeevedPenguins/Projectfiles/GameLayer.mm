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

const float PTM_RATIO = 32.0f;
#define FLOOR_HEIGHT    50.0f
#define SPEED_FACTOR     1.0f
#define MAX_MUNITION        2

CCSprite *projectile;
CCSprite *block;
CGRect firstrect;
CGRect secondrect;
NSMutableArray *blocks = [[NSMutableArray alloc] init];
NSDictionary *currentlevelDescription;



@interface GameLayer ()
-(void) enableBox2dDebugDrawing;
-(void) addSomeJoinedBodies:(CGPoint)pos;
-(void) addNewSpriteAt:(CGPoint)p;
-(b2Vec2) toMeters:(CGPoint)point;
-(CGPoint) toPixels:(b2Vec2)vec;
- (BOOL)gameOver;
- (void)createBullets: (int) count;

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
        
        currentlevelDescription = levelDescription;
        
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

        //Raise to floor height
        b2Vec2 lowerLeftCorner = b2Vec2(0,FLOOR_HEIGHT/PTM_RATIO);
        
        //Raise to floor height, extend to end of game area
		b2Vec2 lowerRightCorner = b2Vec2(screenSize.width*2.0f/PTM_RATIO,FLOOR_HEIGHT/PTM_RATIO);
        
        
		b2Vec2 upperLeftCorner = b2Vec2(0,screenSize.height/PTM_RATIO);
        
		//Extend to end of game area.
        b2Vec2 upperRightCorner =b2Vec2(screenSize.width*2.0f/PTM_RATIO,screenSize.height/PTM_RATIO);
		
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
        
        [self createTargetsWithLevelDescription:levelDescription];

        
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
        
        CCSprite *arm = [CCSprite spriteWithFile:@"catapultarm.png"];

        [self addChild:arm z:-1];
        
        // Setting the properties of our definition
        b2BodyDef armBodyDef;
        armBodyDef.type = b2_dynamicBody;
        //other types of bodies include static (immovable) bodies and kinematic bodies
        armBodyDef.linearDamping = 1;
        //linear damping affects how much the velocity of an object slows over time - this is in addition to friction
        armBodyDef.angularDamping = 1;
        //causes rotations to slow down. A value of 0 means there is no slowdown
        armBodyDef.position.Set(240.0f/PTM_RATIO,(FLOOR_HEIGHT+141.0f)/PTM_RATIO);
        armBodyDef.userData = (__bridge void*)arm; //this tells the Box2D body which sprite to update. This similar to the 'tag' property on buttons
        
        //create a body with the definition we just created
        armBody = world->CreateBody(&armBodyDef);
        //the -> is C++ syntax; it is like calling an object's methods (the CreateBody "method")
        
        //Create a fixture for the arm
        b2PolygonShape armBox;
        b2FixtureDef armBoxDef;
        armBoxDef.shape = &armBox; //geometric shape
        armBoxDef.density = 0.3F; //affects collision momentum and inertia
        armBox.SetAsBox(15.0f/PTM_RATIO, 140.0f/PTM_RATIO);
        //this is based on the dimensions of the arm which you can get from your image editing software of choice
        armFixture = armBody->CreateFixture(&armBoxDef);
        
        // Create a joint to fix the catapult to the floor.
        b2RevoluteJointDef armJointDef;
        armJointDef.Initialize(screenBorderBody, armBody, b2Vec2(230.0f/PTM_RATIO, (FLOOR_HEIGHT+50.0f)/PTM_RATIO));
        
        
        /*When creating the joint you have to specify 2 bodies and the hinge point. You might be thinking: “shouldn’t the catapult’s arm attach to the base?”. Well, in the real world, yes. But in Box2d not necessarily. You could do this but then you’d have to create another body for the base and add more complexity to the simulation.*/
        
        armJointDef.enableMotor = true; // the motor will fight against our motion, sort of like a spring
        armJointDef.motorSpeed  = -5; // this sets the motor to move the arm clockwise, so when you pull it back it springs forward
        armJointDef.maxMotorTorque = 300; //this limits the speed at which the catapult can move
        armJointDef.enableLimit = true;
        armJointDef.lowerAngle  = CC_DEGREES_TO_RADIANS(9);
        armJointDef.upperAngle  = CC_DEGREES_TO_RADIANS(75);//these limit the range of motion of the catapult
        armJoint = (b2RevoluteJoint*)world->CreateJoint(&armJointDef);
		
        [[SimpleAudioEngine sharedEngine] preloadEffect:@"explo2.wav"];
        
        //schedules a call to the update method every frame
		[self scheduleUpdate];
        
        [self performSelector:@selector(resetGame) withObject:nil afterDelay:0.5f];
	}
    
	return self;
}

- (void)createTarget:(NSString*)imageName
          atPosition:(CGPoint)position
            rotation:(CGFloat)rotation
            isCircle:(BOOL)isCircle
            isStatic:(BOOL)isStatic
             isEnemy:(BOOL)isEnemy
{
    //seals are enemies, and since we create a custom Seal class,
    //we have to handle it differently
    CCSprite* sprite;
    if (isEnemy)
    {
        sprite = [[Seal alloc] initWithSealImage];
        [self addChild:sprite z:1];
    }
    else
    {
        sprite = [CCSprite spriteWithFile:imageName];
        [self addChild:sprite z:1];
    }
    
    b2BodyDef bodyDef;
    bodyDef.type = isStatic?b2_staticBody:b2_dynamicBody; //this is a shorthand/abbreviated if-statement
    bodyDef.position.Set((position.x+sprite.contentSize.width/2.0f)/PTM_RATIO,(position.y+sprite.contentSize.height/2.0f)/PTM_RATIO);
    bodyDef.angle = CC_DEGREES_TO_RADIANS(rotation);
    bodyDef.userData = (__bridge void*) sprite;
    b2Body *body = world->CreateBody(&bodyDef);
    
    b2FixtureDef boxDef;
    
    if (isCircle)
    {
        b2CircleShape circle;
        circle.m_radius = sprite.contentSize.width/2.0f/PTM_RATIO;
        boxDef.shape = &circle;
    }
    else
    {
        
        b2PolygonShape box;
        box.SetAsBox(sprite.contentSize.width/2.0f/PTM_RATIO,
                     sprite.contentSize.height/2.0f/PTM_RATIO);
        //contentSize is used to determine the dimensions of the sprite
        boxDef.shape = &box;
        
    }
    if (isEnemy)
        
    {
        boxDef.userData = (void*)1;
        [enemies addObject:[NSValue valueWithPointer:body]];
    }
    
    boxDef.density = 0.5f;
    body->CreateFixture(&boxDef);
    [targets addObject:[NSValue valueWithPointer:body]];
}

- (void)createTargetsWithLevelDescription: (NSDictionary*)levelDescription {
    NSArray *blockDescriptions = [levelDescription objectForKey:@"blocks"];
    
    for (NSDictionary *block in blockDescriptions) {
        NSString *fileName = [block objectForKey:@"spriteName"];
        fileName = [fileName stringByAppendingString:@".png"];
        float x = [[block objectForKey:@"x"] intValue];
        float y = [[block objectForKey:@"y"] intValue];
        
        [self createTarget:fileName atPosition:ccp(x,y) rotation:0.f isCircle:NO isStatic:NO isEnemy:NO];
    }
    
    [self createTarget:@"seal.png" atPosition:CGPointMake(680.0f, FLOOR_HEIGHT + 72.0f) rotation:0.0f isCircle:YES isStatic:NO isEnemy:YES];
    [self createTarget:@"seal.png" atPosition:CGPointMake(740.0f, FLOOR_HEIGHT + 72.0f) rotation:0.0f isCircle:YES isStatic:NO isEnemy:YES];
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

- (void)resetGame
{
    [self createBullets:2]; //load 4 bullets
    [self attachBullet]; //attach the first bullet
    [self createTargetsWithLevelDescription:currentlevelDescription];
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

- (void)resetBullet
{
    if ([enemies count] == 0)
    {
        // game over
        // We'll do something here later
    }
    else if ([self attachBullet])
    {
        [self runAction:[CCMoveTo actionWithDuration:2.0f position:CGPointZero]];
    }
    else
    {
        // We can reset the whole scene here
        // Also, let's do this later
    }
}

//Create the bullets, add them to the list of bullets so they can be referred to later
- (void)createBullets: (int) count
{
    currentBullet = 0;
    CGFloat pos = 52.0f;
    
    if (count > 0)
    {
        // delta is the spacing between penguins
        // 52 is the position o the screen where we want the penguins to start appearing
        // 165 is the position on the screen where we want the penguins to stop appearing
        // 25 is the size of the penguin
        CGFloat delta = (count > 1)?((165.0f - 52.0f - 25.0f) / (count - 1)):0.0f;
        
        bullets = [[NSMutableArray alloc] initWithCapacity:count];
        for (int i=0; i<count; i++, pos+=delta)
        {
            // Create the bullet
            
            CCSprite *sprite = [CCSprite spriteWithFile:@"flyingpenguin.png"]; //create bullet sprite
            [self addChild:sprite z:1];
            
            b2BodyDef bulletBodyDef;
            bulletBodyDef.type = b2_dynamicBody;
            bulletBodyDef.bullet = true; //this tells Box2D to check for collisions more often - sets "bullet" mode on
            bulletBodyDef.position.Set(pos/PTM_RATIO,(FLOOR_HEIGHT+15.0f)/PTM_RATIO);
            bulletBodyDef.userData = (__bridge void*)sprite;
            b2Body *bullet = world->CreateBody(&bulletBodyDef);
            bullet->SetActive(false); //an inactive body does not collide with other bodies
            
            b2CircleShape circle;
            circle.m_radius = 12.0/PTM_RATIO; //you can figure the dimensions out by looking at flyingpenguin.png in image editing software
            
            b2FixtureDef ballShapeDef;
            ballShapeDef.shape = &circle;
            ballShapeDef.density = 0.8f;
            ballShapeDef.restitution = 0.2f; //set the "bounciness" of a body (0 = no bounce, 1 = complete (elastic) bounce)
            ballShapeDef.friction = 0.99f;
            //try changing these and see what happens!
            bullet->CreateFixture(&ballShapeDef);
            
            [bullets addObject:[NSValue valueWithPointer:bullet]];
        }
    }
}

- (BOOL)attachBullet
{
    if (currentBullet < [bullets count])
    {
        bulletBody = (b2Body*)[[bullets objectAtIndex:currentBullet++] pointerValue]; //get next bullet in the list
        bulletBody->SetTransform(b2Vec2(240.0f/PTM_RATIO, (200.0f+FLOOR_HEIGHT)/PTM_RATIO), 0.0f);
        //SetTransform sets the position and rotation of the bulletBody; the syntax is SetTransform( (b2Vec2) position, (float) rotation)
        
        bulletBody->SetActive(true);
        
        b2WeldJointDef weldJointDef;
        weldJointDef.Initialize(bulletBody, armBody, b2Vec2(240.0f/PTM_RATIO,(200.0f+FLOOR_HEIGHT)/PTM_RATIO));
        //syntax is Initialize(bodyA, bodyB, anchor point) - the anchor point is the point of rotation
        
        weldJointDef.collideConnected = false; //collisions between bodies connected by the weld joint are disabled
        
        bulletJoint = (b2WeldJoint*)world->CreateJoint(&weldJointDef);
        return YES;
    }
    
    return NO;
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
    
    if(input.anyTouchBeganThisFrame) //this is when someone's finger first hits the screen
    {
        CGPoint location = input.anyTouchLocation; //get the touch location
        b2Vec2 locationWorld = b2Vec2(location.x/PTM_RATIO, location.y/PTM_RATIO); //convert the location to Box2D coordinates
        
        if (locationWorld.x < armBody->GetWorldCenter().x + 40.0/PTM_RATIO) //if we're touching the catapult area
        {
            b2MouseJointDef md;
            md.bodyA = screenBorderBody;
            md.bodyB = armBody; //the body that is moved
            md.target = locationWorld; //bodyB is "pulled" to the target
            md.maxForce = 2000; //affects the speed that the catapult arm follows your finger
            //we create a mouse joint that can pull the catapult
            mouseJoint = (b2MouseJoint *)world->CreateJoint(&md);
        }
        
    }
    else if(input.anyTouchEndedThisFrame)  // if someone's finger lets go
    {
        if (armJoint->GetJointAngle() >= CC_DEGREES_TO_RADIANS(20))
        {
            releasingArm = YES;
        }
        
        if (mouseJoint != nil)
        {
            //destroying the mouse joint lets the catapult motor rotate it back to its original position
            world->DestroyJoint(mouseJoint);
            [self performSelector:@selector(resetBullet) withObject:nil afterDelay:5.0f];
            mouseJoint = nil;
        }
        
        if (self.usedMunition < MAX_MUNITION) {
            [self createBullets:1];
            self.usedMunition++;
        }
    }
    else if(input.touchesAvailable) //if they are dragging the catapult back
    {
        if (mouseJoint == nil) return;
        CGPoint location = input.anyTouchLocation;
        location = [[CCDirector sharedDirector] convertToGL:location];
        b2Vec2 locationWorld = b2Vec2(location.x/PTM_RATIO, location.y/PTM_RATIO);
        
        mouseJoint->SetTarget(locationWorld); //moves the mouseJoint target to the touch location, which in turn pulls the catapult arm
    }
    
    //get all the bodies in the world
    for (b2Body* body = world->GetBodyList(); body != nil; body = body->GetNext())
    {
        //get the sprite associated with the body
        CCSprite* sprite = (__bridge CCSprite*)body->GetUserData();
        if (sprite != NULL)
        {
            // update the sprite's position to where their physics bodies are
            sprite.position = [self toPixels:body->GetPosition()];
            float angle = body->GetAngle();
            sprite.rotation = CC_RADIANS_TO_DEGREES(angle) * -1;
        }
    }
    
    
    // Arm is being released and bullet attached
    if (releasingArm && bulletJoint)
    {
        // Check if the arm has reached the end so we can let the bullet go
        if (armJoint->GetJointAngle() <= CC_DEGREES_TO_RADIANS(10))
        {
            releasingArm = NO; //reset state of arm
            
            // Destroy joint so the bullet will be free
            world->DestroyJoint(bulletJoint);
            bulletJoint = nil;
            
        }
    }
    
    float timeStep = 0.03f;
    int32 velocityIterations = 8;
    int32 positionIterations = 1;
    world->Step(timeStep, velocityIterations, positionIterations);
    
    //Bullet is moving.
    if (bulletBody && bulletJoint == nil)
    {
        b2Vec2 position = bulletBody->GetPosition();
        CGPoint myPosition = self.position;
        CGSize screenSize = [CCDirector sharedDirector].winSize;
        
        // Move the camera.
        if (position.x > screenSize.width / 2.0f / PTM_RATIO)
            //if the bullet is past the edge of the screen
        {
            //self.position refers to the window's position - subtracting from self.position moves the screen to the right
            //meaning that the screen position is negative as it moves
            //only shift the screen a maximum of one screen size to the right
            myPosition.x = -MIN(screenSize.width * 2.0f - screenSize.width, position.x * PTM_RATIO - screenSize.width / 2.0f);
            self.position = myPosition;
            
        }
    }
}

// convenience method to convert a b2Vec2 to a CGPoint
-(CGPoint) toPixels:(b2Vec2)vec
{
	return ccpMult(CGPointMake(vec.x, vec.y), PTM_RATIO);
}


@end
