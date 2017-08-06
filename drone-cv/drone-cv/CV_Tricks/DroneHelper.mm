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
        _NEDVelocityX = 10;
        _NEDVelocityY = 10;
        _NEDVelocityZ = 10;
        _heightAboveHome = 10;
        _roll = 10;
        _pitch = 10;
        _yaw = 10;
        _isFlying = 10;
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

#pragma mark FlightControllerDelegate
-(void)flightController:(DJIFlightController *)fc didUpdateState:(DJIFlightControllerState *)state
{
    //self.debug1.text = [NSString stringWithFormat:@"h=%.3f",  state.altitude ];
    [self setCurrentState:state];
}

#pragma mark Enable and Disable virtual stick
- (BOOL) enterVirtualStickMode
{
    __block BOOL result=TRUE;
    DJIBaseProduct *p = [DJISDKManager product];
    if(p == nil) {
        NSLog(@"enterVirtualStickMode failed: no product connected");
        return FALSE;
    }
    // disable gesture mode
    if([p.model isEqual: DJIAircraftModelNameSpark]) {
        [[DJISDKManager missionControl].activeTrackMissionOperator setGestureModeEnabled:NO withCompletion:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"Set Gesture mode enabled failed");
                result = FALSE;
            }
        }];
    }
    if(!result) return FALSE;

    // Enter the virtual stick mode with some default settings
    DJIFlightController *fc = [self fetchFlightController];
    if(fc == nil) {
        NSLog(@"enterVirtualStickMode failed: can't fetch FC");
        return FALSE;
    }
    
    fc.yawControlMode            = DJIVirtualStickYawControlModeAngularVelocity;
    fc.rollPitchControlMode      = DJIVirtualStickRollPitchControlModeVelocity;
    fc.rollPitchCoordinateSystem = DJIVirtualStickFlightCoordinateSystemBody;
    //DJIVirtualStickFlightCoordinateSystemBody;
    [fc setVirtualStickModeEnabled:YES withCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"Enter VirtualStickControlMode Failed");
            result = FALSE;
        }
        else {
            NSLog(@"Enter VirtualStickControlMode Succeeded");
        }
    }];
    return result;
}

- (BOOL) exitVirtualStickMode
{
    __block BOOL result = TRUE;
    DJIFlightController* fc = [self fetchFlightController];
    if (fc) {
        [fc setVirtualStickModeEnabled:NO withCompletion:^(NSError * _Nullable error) {
            if (error){
                NSLog(@"Exit VirtualStickControlMode Failed");
                result = FALSE;
            } else{
                NSLog(@"Exit Virtual Stick Mode:Succeeded");
            }
        }];
    }
    else
    {
        NSLog(@"Component not exist.");
        result = FALSE;
    }
    return result;
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

#pragma mark Takeoff and land
- (BOOL) takeoff
{
    __block BOOL result = FALSE;
    DJIFlightController* fc = [self fetchFlightController];
    if (fc)
    {
        [fc startTakeoffWithCompletion:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"Takeoff failed!");
            }
            else {
                result = TRUE;
            }
        }];
    }
    return result;
}

- (BOOL) land
{
    __block BOOL result = FALSE;
    DJIFlightController* fc = [self fetchFlightController];
    if (fc)
    {
        [fc startLandingWithCompletion:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"Land failed!");
            }
            else {
                result = TRUE;
            }
        }];
    }
    return result;
}

#pragma mark Gimbal Pitch
- (BOOL) setGimbalPitchDegree : (float) pitchAngleDegree
{
    __block BOOL result = TRUE;
    DJIGimbal * myGimbal = [self fetchGimbal];
    if(myGimbal == nil)
    {
        return FALSE;
    }
    DJIGimbalRotation *rotation = [DJIGimbalRotation gimbalRotationWithPitchValue:@(pitchAngleDegree)
                                                                        rollValue:0
                                                                         yawValue:0 time:(fabs(pitchAngleDegree)/90.0)
                                                                             mode:DJIGimbalRotationModeAbsoluteAngle];
    
    [myGimbal rotateWithRotation:rotation completion:^(NSError * _Nullable error) {
        if (error)
        {
            //[self showAlertViewWithTitle:@"rotateWithRotation failed" withMessage:@"Failed"];
            //self.debug2.text = @"rotation failed";
            result = FALSE;
        }
    }];
    return result;
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
