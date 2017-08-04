//
//  DroneHelper.mm
//  drone-cv
//
//  Created by Zhiyuan Li on 7/27/17.
//  Copyright © 2017 dji. All rights reserved.
//

#import "DroneHelper.h"

@implementation DroneHelper


-(instancetype)init
{
    self = [super init];
    if (self) {
        self.NEDVelocityX = 10;
        self.NEDVelocityY = 10;
        self.NEDVelocityZ = 10;
        self.heightAboveHome = 10;
        self.roll = 10;
        self.pitch = 10;
        self.yaw = 10;
        self.isFlying = 10;
    }
    return self;
}

- (void) setCurrentState:(DJIFlightControllerState *) state
{
    self.NEDVelocityX = state.velocityX;
    self.NEDVelocityY = state.velocityY;
    self.heightAboveHome = state.altitude;
    self.NEDVelocityZ = state.velocityZ;
    self.roll = state.attitude.roll;
    self.pitch = state.attitude.pitch;
    self.yaw = state.attitude.yaw;
    self.isFlying = state.isFlying;
}

- (BOOL) enableVirtualStick
{
    DJIBaseProduct *p = [DJISDKManager product];
    if(p == nil) {
        NSLog(@"enableVirtualStick failed: no product connected");
        return FALSE;
    }
    // disable gesture mode
    if([p.model isEqual: DJIAircraftModelNameSpark]) {
        [[DJISDKManager missionControl].activeTrackMissionOperator setGestureModeEnabled:NO withCompletion:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"Set Gesture mode enabled failed");
            }
            else {
                NSLog(@"Set Gesture mode enabled Succeeded");
            }
        }];
    }

    
    // Enter the virtual stick mode with some default settings
    DJIFlightController *fc = [self fetchFlightController];
    if(fc == nil) {
        NSLog(@"enableVirtualStick failed: can't fetch FC");
        return FALSE;
    }
    
    fc.yawControlMode            = DJIVirtualStickYawControlModeAngle;
    fc.rollPitchControlMode      = DJIVirtualStickRollPitchControlModeVelocity;
    fc.rollPitchCoordinateSystem = DJIVirtualStickFlightCoordinateSystemBody;
    //DJIVirtualStickFlightCoordinateSystemBody;
    [fc setVirtualStickModeEnabled:YES withCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"Enable VirtualStickControlMode Failed");
        }
        else {
            NSLog(@"Enable VirtualStickControlMode Succeeded");
        }
    }];
    return TRUE;
}

#pragma mark Drone movement
- (BOOL) sendMovementCommand:(DJIVirtualStickFlightControlData) vsSetpoint
{
    DJIFlightController *fc = [self fetchFlightController];
    if(fc == nil) {
        NSLog(@"sendMovementCommand failed: can't fetch FC");
        return FALSE;
    }
    
    fc.isVirtualStickAdvancedModeEnabled = YES;
    
    [fc sendVirtualStickFlightControlData:vsSetpoint withCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"Send FlightControl Data Failed %@", error.description);
        }
    }];
    return TRUE;
}


#pragma mark Get Drone Components
- (DJICamera*) fetchCamera {
    if (![DJISDKManager product]) {
        return nil;
    }
    return [DJISDKManager product].camera;
}

- (DJIFlightController*) fetchFlightController {
    if (![DJISDKManager product]) {
        return nil;
    }
    
    if ([[DJISDKManager product] isKindOfClass:[DJIAircraft class]]) {
        return ((DJIAircraft*)[DJISDKManager product]).flightController;
    }
    
    return nil;
}

- (DJIGimbal*) fetchGimbal {
    if (![DJISDKManager product]) {
        return nil;
    }
    
    if ([[DJISDKManager product] isKindOfClass:[DJIAircraft class]]) {
        return ((DJIAircraft*)[DJISDKManager product]).gimbal;
    }
    else if ([[DJISDKManager product] isKindOfClass:[DJIHandheld class]]) {
        return ((DJIHandheld*)[DJISDKManager product]).gimbal;
    }
    
    return nil;
}

@end
