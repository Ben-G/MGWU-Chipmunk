/*
 * Kobold2D™ --- http://www.kobold2d.org
 *
 * Copyright (c) 2010-2011 Steffen Itterheim. 
 * Released under MIT License in Germany (LICENSE-Kobold2D.txt).
 */

#import "ContactListener.h"
#import "cocos2d.h"

void ContactListener::BeginContact(b2Contact* contact)
{
}

void ContactListener::EndContact(b2Contact* contact)
{
}

void ContactListener::PreSolve(b2Contact* contact,
                               const b2Manifold* oldManifold) {
}

void ContactListener::PostSolve(b2Contact* contact,
                                const b2ContactImpulse* impulse)
{
    bool isAEnemy = contact->GetFixtureA()->GetUserData() != NULL; //is A
    bool isBEnemy = contact->GetFixtureB()->GetUserData() != NULL;
    
    if (isAEnemy || isBEnemy)
    {
        // Should the body break?
        int32 count = contact->GetManifold()->pointCount;
        //stores # of points of contact
        
        float32 maxImpulse = 0.0f;
        for (int32 i = 0; i < count; ++i)
        {
            maxImpulse = b2Max(maxImpulse, impulse->normalImpulses[i]);
            //this tests the impulse along each point of contact, and finds the maximum
        }
        
        if (maxImpulse > 1.0f)
        {
            // Flag the enemies we want to destroy later
            if (isAEnemy)
                ((__bridge CCSprite*) contact->GetFixtureA()->GetBody()->GetUserData()).tag=2;
            if (isBEnemy)
                ((__bridge CCSprite*) contact->GetFixtureB()->GetBody()->GetUserData()).tag=2;
            //we access the sprite that corresponds to the body through GetUserData() and set its tag to 2
        }
    }
}