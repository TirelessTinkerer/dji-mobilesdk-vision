//
//  Drone Helper.h
//  drone-cv
//
//  Created by Zhiyuan Li on 7/27/17.
//  Copyright © 2017 dji. All rights reserved.
//

#import <DJISDK/DJISDK.h>
#import <Foundation/Foundation.h>

@interface DroneHelper : NSObject <DJIFlightControllerDelegate>

@property(nonatomic, readwrite) float NEDVelocityX;
@property(nonatomic, readwrite) float NEDVelocityY;
@property(nonatomic, assign) float NEDVelocityZ;
@property(nonatomic, readwrite) double heightAboveHome;
@property(nonatomic, assign) double roll;
@property(nonatomic, assign) double pitch;
@property(nonatomic, assign) double yaw;
@property(nonatomic, assign) BOOL   isFlying;


//- (void) setCurrentState:(DJIFlightControllerState *) state;
- (BOOL) sendMovementCommand:(DJIVirtualStickFlightControlData) vsSetpoint;
- (BOOL) setGimbalPitchDegree : (float) pitchAngleDegree;
- (BOOL) enterVirtualStickMode;
- (BOOL) exitVirtualStickMode;
- (BOOL) setVerticleModeToAbsoluteHeight;
- (BOOL) setVerticleModeToVelocity;
- (BOOL) takeoff;
- (BOOL) land;

@end
