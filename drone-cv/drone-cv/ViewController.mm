//
//  ViewController.m
//  drone-cv
//
//  Created by Arjun Menon on 7/6/17.
//  Copyright © 2017 dji. All rights reserved.
//

#import <opencv2/opencv.hpp>
#import "ViewController.h"
#import <DJISDK/DJISDK.h>
#import <VideoPreviewer/VideoPreviewer.h>
#import "OpenCVConversion.h"

#ifdef __cplusplus
  #include <vector>
  #include <opencv2/imgproc/imgproc.hpp>
  #include <opencv2/objdetect/objdetect.hpp>
  #include <opencv2/video/tracking.hpp>
#include "MagicInAir.h"
using namespace std;
#endif

#define PHOTO_NUMBER 4
#define ROTATE_ANGLE 90

#define weakSelf(__TARGET__) __weak typeof(self) __TARGET__=self
#define weakReturn(__TARGET__) if(__TARGET__==nil)return;


@interface ViewController()<DJIVideoFeedListener, DJISDKManagerDelegate>
{
    SimpleFaceDetector* myFaceDetector;
}

//@property (atomic) CLLocationCoordinate2D aircraftLocation;
@property (atomic) double aircraftAltitude;
@property (atomic) DJIGPSSignalLevel gpsSignalLevel;
@property (atomic) double aircraftYaw;

@property (weak, nonatomic) IBOutlet UIView *fpvPreview;
@property (weak, nonatomic) IBOutlet UIImageView *imgView;
@property (strong, nonatomic) UIImage *myImage;
@property (weak, nonatomic) IBOutlet UILabel *debug1;
@property (weak, nonatomic) IBOutlet UILabel *debug2;
@property (weak, nonatomic) NSTimer *myTimer;
@property (nonatomic, copy, nullable) void (^processFrame)(UIImage *frame);

@property (nonatomic, copy) void (^defaultProcess)(UIImage *frame);
@property (atomic) enum ImgProcess_Mode imgProcType;

@property (weak, nonatomic) IBOutlet UIButton *laplaceFilter;
@property (weak, nonatomic) IBOutlet UIButton *gaussBlur;
@property (weak, nonatomic) IBOutlet UIButton *humanDetect;
@property (weak, nonatomic) IBOutlet UIButton *testGimbal;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view, typically from a nib.
    [self registerApp];
    self.imgView.contentMode = UIViewContentModeScaleAspectFit;
    [self.imgView setBackgroundColor:[UIColor redColor]];
    
    UIImage *image = [UIImage imageNamed:@"mavic.jpg"];
    if(image != nil)
        self.imgView.image = image;

    self.myTimer=nil;
    
    self.defaultProcess = ^(UIImage *frame){
        cv::Mat colorImg = [OpenCVConversion cvMatFromUIImage:frame];
        if(colorImg.cols == 0)
        {
            NSLog(@"Invalid frame!");
            return;
        }
        cv::resize(colorImg, colorImg, cv::Size(480, 360));
        
        // The default image processing routine just put a text to the resized image
        putText(colorImg, "Default" , cv::Point(150, 40), 1, 4, cv::Scalar(255, 255, 255), 2, 8, 0);
        
        [self.imgView setImage:[OpenCVConversion UIImageFromCVMat:colorImg]];
    };
    
    self.imgProcType = IMG_PROC_DEFAULT;

   // myFaceDetector = new SimpleFaceDetector("haarcascade_frontalface_alt.xml");
    myFaceDetector = new SimpleFaceDetector("lbpcascade_frontalface");

}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    [self resetVideoPreview];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


//////////////////////// The following functions deals with App Registration
- (void)registerApp
{
    //Please enter your App key in the "DJISDKAppKey" key in info.plist file.
    [DJISDKManager registerAppWithDelegate:self];
}

- (void)showAlertViewWithTitle:(NSString *)title withMessage:(NSString *)message
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}


#pragma mark DJISDKManagerDelegate Method
- (void)appRegisteredWithError:(NSError *)error
{
    NSString* message = @"Register App Successed!";
    if (error) {
        message = @"Failed! Please check your App Key and network.";
    }
    
    NSLog(message);
    [self showAlertViewWithTitle:@"Register App" withMessage:message];
    
    [DJISDKManager startConnectionToProduct];
    //        [DJISDKManager enableBridgeModeWithBridgeAppIP:@"192.168.0.107"];
}

- (void)productConnected:(DJIBaseProduct* _Nullable)product
{
    if(product)
    {
        [self setupVideoPreviewer]; // Implemented below
        
        DJICamera * myCamera = [self fetchCamera];
        DJIGimbal * myGimbal = [self fetchGimbal];
        DJIFlightController * myFC = [self fetchFlightController];
        
        if(myCamera == nil)
        {
            [self showAlertViewWithTitle:@"Product Connected" withMessage:@"Failed to fetch camera"];
        }
        else if(myGimbal == nil)
        {
            [self showAlertViewWithTitle:@"Product Connected" withMessage:@"Failed to fetch gimbal"];
        }
        else if(myFC == nil)
        {
            [self showAlertViewWithTitle:@"Product Connected" withMessage:@"Failed to fetch FC"];
        }
        else
        {
            [self showAlertViewWithTitle:@"Product Connected" withMessage:@"All components fetched"];
        }
    }
    else
    {
        [self showAlertViewWithTitle:@"Product Connected" withMessage:@"Error!"];
    }
}

- (void) productDisconnected
{
    [self resetVideoPreview]; // Implemented below
}

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


// Called by productConnected
- (void) setupVideoPreviewer
{
    self.debug1.text = @"Connected!";
    self.debug2.text = @"Init-ed";
    [[VideoPreviewer instance] setView:self.fpvPreview];
    [[DJISDKManager videoFeeder].primaryVideoFeed addListener:self withQueue:nil];
    [[VideoPreviewer instance] start];
    
    self.myTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(timerCallback) userInfo:nil repeats:YES];
    
    // This is where you define your image processing method
    self.processFrame = self.defaultProcess;
}

// Called by productDisconnected
- (void) resetVideoPreview
{
    self.debug1.text = @"Disconnected!";
    [[VideoPreviewer instance] unSetView];
    [[DJISDKManager videoFeeder].primaryVideoFeed removeListener:self];
    [self.myTimer invalidate];
}

#pragma mark - DJIVideoFeedListener
-(void)videoFeed:(DJIVideoFeed *)videoFeed didUpdateVideoData:(NSData *)videoData {
    [[VideoPreviewer instance] push:(uint8_t *)videoData.bytes length:(int)videoData.length];
}
//
//- (void)takeSnapshot
//{
//    UIView *snapshot = [self.fpvPreview snapshotViewAfterScreenUpdates:YES];
//    snapshot.tag = 100001;
//    
//    if ([self.imgView viewWithTag:100001]) {
//        [[self.imgView viewWithTag:100001] removeFromSuperview];
//    }
//    
//    [self.imgView addSubview:snapshot];
//    self.debug2.text = [NSString stringWithFormat:@"%d", self.counter++];
//}

-(void) timerCallback
{
    //todo: currently the whole processFrame is called inside glView
    //we may consider copy out the UIImage and process it in timer
    //callback
    [[VideoPreviewer instance] snapshotPreview:self.processFrame];
}

// Filter Buttons
- (IBAction)doLaplace:(id)sender;
{
    if(self.imgProcType == IMG_PROC_LAPLACIAN)
    {
        self.imgProcType = IMG_PROC_DEFAULT;
        self.processFrame = self.defaultProcess;
        self.debug2.text = @"Default";
    }
    else
    {
        self.imgProcType = IMG_PROC_LAPLACIAN;
        self.processFrame =
        ^(UIImage *frame){
            cv::Mat colorImg = [OpenCVConversion cvMatGrayFromUIImage:frame];
            if(colorImg.cols == 0)
            {
                NSLog(@"Invalid frame!");
                return;
            }
            cv::resize(colorImg, colorImg, cv::Size(480, 360));
            
            //TODO CMU: insert the image processing function call here
            //Implement the function in MagicInAir.mm.
            filterLaplace(colorImg, 3);
            
            [self.imgView setImage:[OpenCVConversion UIImageFromCVMat:colorImg]];
        };
        self.debug2.text = @"Laplace";
    }
}

- (IBAction)doGaussian:(id)sender;
{
    if(self.imgProcType == IMG_PROC_BLUR_GAUSSIAN)
    {
        self.imgProcType = IMG_PROC_DEFAULT;
        self.processFrame = self.defaultProcess;
        self.debug2.text = @"Default";
    }
    else
    {
        self.imgProcType = IMG_PROC_BLUR_GAUSSIAN;
        self.processFrame =
        ^(UIImage *frame){
            cv::Mat colorImg = [OpenCVConversion cvMatGrayFromUIImage:frame];
            if(colorImg.cols == 0)
            {
                NSLog(@"Invalid frame!");
                return;
            }
            cv::resize(colorImg, colorImg, cv::Size(480, 360));

            //TODO CMU: insert the image processing function call here
            //Implement the function in MagicInAir.mm.
            filterBlurHomogeneousAccelerated(colorImg, 21);
            
            [self.imgView setImage:[OpenCVConversion UIImageFromCVMat:colorImg]];
        };
        self.debug2.text = @"Laplace";
    }
}

//-(void) detect(cv::Mat &img, cv::CascadeClassifier &detectorBody)
//{
//    vector<cv::Rect> human;
//    cvtColor(img, img, CV_BGR2GRAY);
//
//    detectorBody.detectMultiScale(img, human, 1.1, 2, 0 | 1, cv::Size(40,70), cv::Size(80, 300));
//    // Draw results from detectorBody into original colored image
//    if (human.size() > 0) {
//        for (int gg = 0; gg < human.size(); gg++) {
//            cv::rectangle(img, human[gg].tl(), human[gg].br(), Scalar(0,0,255), 2, 8, 0);
//        }
//    }
//}

- (IBAction)doDetectFace:(id)sender;
{
    if(self.imgProcType == IMG_PROC_FACE_DETECT)
    {
        self.imgProcType = IMG_PROC_DEFAULT;
        self.processFrame = self.defaultProcess;
        self.debug2.text = @"Default";
    }
    else
    {
        self.imgProcType = IMG_PROC_FACE_DETECT;
        self.processFrame =
        ^(UIImage *frame){
            cv::Mat colorImg = [OpenCVConversion cvMatGrayFromUIImage:frame];
            if(colorImg.cols == 0)
            {
                NSLog(@"Invalid frame!");
                return;
            }
            cv::resize(colorImg, colorImg, cv::Size(480, 360));
            
            //TODO CMU: insert the image processing function call here
            //Implement the function in MagicInAir.mm.
            NSInteger f =myFaceDetector->detectFaceInMat(colorImg);
            
            [self.imgView setImage:[OpenCVConversion UIImageFromCVMat:colorImg]];
            self.debug2.text = [NSString stringWithFormat:@"%d faces", f];
        };
    }
}

- (IBAction)doDetectAR:(id)sender
{
    if(self.imgProcType == IMG_PROC_USER_1)
    {
        self.imgProcType = IMG_PROC_DEFAULT;
        self.processFrame = self.defaultProcess;
        self.debug2.text = @"Default";
    }
    else
    {
        self.imgProcType = IMG_PROC_USER_1;
        self.processFrame =
        ^(UIImage *frame){
            cv::Mat colorImg = [OpenCVConversion cvMatGrayFromUIImage:frame];
            if(colorImg.cols == 0)
            {
                NSLog(@"Invalid frame!");
                return;
            }
            cv::resize(colorImg, colorImg, cv::Size(480, 360));
            
            //TODO CMU: insert the image processing function call here
            //Implement the function in MagicInAir.mm.
            NSInteger n=detectARTag(colorImg);
            
            [self.imgView setImage:[OpenCVConversion UIImageFromCVMat:colorImg]];
            self.debug2.text = [NSString stringWithFormat:@"%d Tags", n];
        };
    }
}

/**
 Demo how to move the gimbal to face forward and down.
 */
- (IBAction)gimbalRun:(id)sender;
{
    enum {FORWARD=0, DOWN=1};
    static int action = FORWARD;
    
    DJIGimbal * myGimbal = [self fetchGimbal];
    if(myGimbal == nil)
    {
         [self showAlertViewWithTitle:@"fetch gimbal" withMessage:@"Failed"];
    }
    else
    {
        int pitchRotation;
        if(action == FORWARD)
            pitchRotation = 0;
        else
            pitchRotation = -85;
        
        DJIGimbalRotation *rotation = [DJIGimbalRotation gimbalRotationWithPitchValue:@(pitchRotation)
                                                                            rollValue:0
                                                                             yawValue:0 time:2
                                                                                 mode:DJIGimbalRotationModeAbsoluteAngle];
        
        [myGimbal rotateWithRotation:rotation completion:^(NSError * _Nullable error) {
            if (error)
            {
                [self showAlertViewWithTitle:@"rotateWithRotation failed" withMessage:@"Failed"];
            }
        }];
        
        action = (action == FORWARD) ? DOWN : FORWARD;
    }
}

/**
 Demo how to take off and land.
 */
- (IBAction)onTakeoffButtonClicked:(id)sender
{
    enum {TAKEOFF=0, LAND=1};
    static int action = TAKEOFF;
    
    DJIFlightController* fc = [self fetchFlightController];
    if (fc) {
        if(action == TAKEOFF)
        {
            [fc startTakeoffWithCompletion:^(NSError * _Nullable error) {
                if (error) {
                    [self showAlertViewWithTitle:@"takeoff" withMessage:@"Failed"];
                }
                else
                {
                    [self showAlertViewWithTitle:@"takeoff" withMessage:@"Succeeded"];
                }
            }];
        }
        else
        {
            [fc startLandingWithCompletion:^(NSError * _Nullable error) {
                if (error) {
                    [self showAlertViewWithTitle:@"Landing" withMessage:@"Failed"];
                }
                else
                {
                    [self showAlertViewWithTitle:@"Landing" withMessage:@"Succeeded"];
                }
            }];
        }
    }
    else
    {
        [self showAlertViewWithTitle:@"Component" withMessage:@"Not exist"];
    }
    action = (action == TAKEOFF)? LAND : TAKEOFF;
}

- (IBAction)onDroneMoveClicked:(id)sender
{
    [self enableVS];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self executeVirtualStickControl];
    });
}

- (void) enableVS
{
    // disable gesture mode
    if([[DJISDKManager product].model isEqual: DJIAircraftModelNameSpark])
    {
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
    fc.yawControlMode = DJIVirtualStickYawControlModeAngle;
    fc.rollPitchControlMode = DJIVirtualStickRollPitchControlModeVelocity;
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

}

- (void)executeVirtualStickControl
{
    __weak DJICamera *camera = [self fetchCamera];
    
    for(int i = 0;i < PHOTO_NUMBER; i++){
        
        float yawAngle = ROTATE_ANGLE*i;
        NSLog(@"Yaw angle=%f", yawAngle);
        if (yawAngle > 180.0) { //Filter the angle between -180 ~ 0, 0 ~ 180
            yawAngle = yawAngle - 360;
        }
        
        NSTimer *timer =  [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(rotateDrone:) userInfo:@{@"YawAngle":@(yawAngle)} repeats:YES];
        [timer fire];
        
        [[NSRunLoop currentRunLoop]addTimer:timer forMode:NSDefaultRunLoopMode];
        [[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
        
        [timer invalidate];
        timer = nil;
        
        sleep(2);
    }
    
    DJIFlightController *flightController = [self fetchFlightController];
    [flightController setVirtualStickModeEnabled:NO withCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"Disable VirtualStickControlMode Failed");
            DJIFlightController *flightController = [self fetchFlightController];
            [flightController setVirtualStickModeEnabled:NO withCompletion:nil];
        }
    }];
    
    weakSelf(target);
    dispatch_async(dispatch_get_main_queue(), ^{
        weakReturn(target);
        [target showAlertViewWithTitle:@"Capture Photos" withMessage:@"Capture finished"];
    });
}

- (void)rotateDrone:(NSTimer *)timer
{
    NSDictionary *dict = [timer userInfo];
    float yawAngle = [[dict objectForKey:@"YawAngle"] floatValue];
    
    DJIFlightController *flightController = [self fetchFlightController];
    
    DJIVirtualStickFlightControlData vsFlightCtrlData;
    vsFlightCtrlData.pitch = 0;
    vsFlightCtrlData.roll = 0;
    vsFlightCtrlData.verticalThrottle = 0;
    vsFlightCtrlData.yaw = yawAngle;
    
    flightController.isVirtualStickAdvancedModeEnabled = YES;
    
    [flightController sendVirtualStickFlightControlData:vsFlightCtrlData withCompletion:^(NSError * _Nullable error) {
        if (error) {
            NSLog(@"Send FlightControl Data Failed %@", error.description);
        }
    }];
    
}
@end
