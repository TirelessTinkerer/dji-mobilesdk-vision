//
//  ViewController.m
//  drone-cv
//
//  Created by Zhiyuan Li on 7/6/17.
//  Copyright © 2017 dji. All rights reserved.
//

#import <opencv2/opencv.hpp>

#import "ViewController.h"
#import <DJISDK/DJISDK.h>
#import <VideoPreviewer/VideoPreviewer.h>
#import "OpenCVConversion.h"
#import "DroneHelper.h"
#ifdef __cplusplus
  #include <vector>
  #include <opencv2/imgproc/imgproc.hpp>
  #include <opencv2/objdetect/objdetect.hpp>
  #include <opencv2/video/tracking.hpp>
  #include <algorithm>
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

@property (weak, nonatomic) IBOutlet UIView *viewLive;
@property (weak, nonatomic) IBOutlet UIImageView *viewProcessed;

@property (weak, nonatomic) IBOutlet UILabel *debug1;
@property (weak, nonatomic) IBOutlet UILabel *debug2;
@property (weak, nonatomic) IBOutlet UILabel *telemetry;

@property (weak, nonatomic) NSTimer *myTimer;

@property (nonatomic, copy, nullable) void (^processFrame)(UIImage *frame);
@property (nonatomic, copy) void (^defaultProcess)(UIImage *frame);

@property (strong, nonatomic) DroneHelper *spark;

@property (atomic) enum ImgProcess_Mode imgProcType;

// Buttons
@property (weak, nonatomic) IBOutlet UIButton *btnLaplace;
@property (weak, nonatomic) IBOutlet UIButton *btnBlur;
@property (weak, nonatomic) IBOutlet UIButton *btnFaceDetect;
@property (weak, nonatomic) IBOutlet UIButton *btnGimbal;
@property (weak, nonatomic) IBOutlet UIButton *btnTakeoffLand;
@property (weak, nonatomic) IBOutlet UIButton *btnMoveTest;
@property (weak, nonatomic) IBOutlet UIButton *btnArucoTag;
@property (weak, nonatomic) IBOutlet UIButton *btnAR;

@property (atomic) double aircraftAltitude;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view, typically from a nib.
    [self registerApp];
    self.viewProcessed.contentMode = UIViewContentModeScaleAspectFit;
    [self.viewProcessed setBackgroundColor:[UIColor clearColor]];

    UIImage *image = [UIImage imageNamed:@"mavic_air.jpg"];
    if(image != nil)
        self.viewProcessed.image = image;

    self.myTimer=nil;

    // We define the default frame processing function (block)
    // to be just add a "Default" label on the resized image
    self.defaultProcess = ^(UIImage *frame){
        cv::Mat colorImg = [OpenCVConversion cvMatFromUIImage:frame];
        if(colorImg.cols == 0) {
            NSLog(@"Invalid frame!");
            return;
        }
        cv::resize(colorImg, colorImg, cv::Size(480, 360));

        // The default image processing routine just put a text to the resized image
        putText(colorImg, "Default" , cv::Point(150, 40), 1, 4, cv::Scalar(255, 255, 255), 2, 8, 0);

        [self.viewProcessed setImage:[OpenCVConversion UIImageFromCVMat:colorImg]];
    };

    self.imgProcType = IMG_PROC_DEFAULT;

    myFaceDetector = new SimpleFaceDetector("lbpcascade_frontalface");
    self.spark = [[DroneHelper alloc] init];

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

#pragma mark App Register
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
    NSString* message = @"Register:OK!";
    if (error) {
        message = [NSString stringWithFormat:@"Register:Failed. %@"];
    }

    self.debug1.text = message;
    NSLog(message);

    [DJISDKManager startConnectionToProduct];

    //Use the following line if you are debugging with bridge
    //[DJISDKManager enableBridgeModeWithBridgeAppIP:@"192.168.0.107"];
}

- (void)productConnected:(DJIBaseProduct* _Nullable)product
{
    if(product)
    {
        [self setupVideoPreviewer]; // Implemented below

        DJICamera * myCamera = [self fetchCamera];
        DJIGimbal * myGimbal = [self fetchGimbal];
        DJIFlightController * myFC = [self fetchFlightController];

        if(myCamera == nil){
            [self showAlertViewWithTitle:@"Product Connected" withMessage:@"Failed to fetch camera"];
        }
        else if(myGimbal == nil){
            [self showAlertViewWithTitle:@"Product Connected" withMessage:@"Failed to fetch gimbal"];
        }
        else if(myFC == nil){
            [self showAlertViewWithTitle:@"Product Connected" withMessage:@"Failed to fetch FC"];
        }
        else{
            [self showAlertViewWithTitle:@"Product Connected" withMessage:@"All components fetched"];
            myFC.delegate = self.spark;
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


// Called by productConnected
- (void) setupVideoPreviewer
{
    self.debug1.text = @"Connected!";
    self.debug2.text = @"Init-ed";
    [[VideoPreviewer instance] setView:self.viewLive];
    [[DJISDKManager videoFeeder].primaryVideoFeed addListener:self withQueue:nil];
    [[VideoPreviewer instance] start];

    self.myTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                    target:self
                                                  selector:@selector(timerCallback)
                                                  userInfo:nil
                                                   repeats:YES];

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


-(void) timerCallback
{
    [[VideoPreviewer instance] snapshotPreview:self.processFrame];
    self.telemetry.text = [NSString stringWithFormat:@"h=%.2f\n\
                                                       vx=%.2f\n\
                                                       vy=%.2f\n\
                                                       vz=%.2f\n\
                                                       yaw=%.2f\n\ pitch=%.2f\
                                                       roll=%.2f",
                           self.spark.heightAboveHome,
                           self.spark.NEDVelocityX, self.spark.NEDVelocityY, self.spark.NEDVelocityZ,
                           self.spark.yaw, self.spark.pitch, self.spark.roll];
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
            cv::Mat grayImg = [OpenCVConversion cvMatGrayFromUIImage:frame];
            if(grayImg.cols == 0)
            {
                NSLog(@"Invalid frame!");
                return;
            }
            cv::resize(grayImg, grayImg, cv::Size(480, 360));

            //TODO CMU: insert the image processing function call here
            //Implement the function in MagicInAir.mm.
            filterLaplace(grayImg, 3);

            [self.viewProcessed setImage:[OpenCVConversion UIImageFromCVMat:grayImg]];
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
            cv::Mat grayImg = [OpenCVConversion cvMatGrayFromUIImage:frame];
            if(grayImg.cols == 0)
            {
                NSLog(@"Invalid frame!");
                return;
            }
            cv::resize(grayImg, grayImg, cv::Size(480, 360));

            //TODO CMU: insert the image processing function call here
            //Implement the function in MagicInAir.mm.
            filterBlurHomogeneousAccelerated(grayImg, 21);

            [self.viewProcessed setImage:[OpenCVConversion UIImageFromCVMat:grayImg]];
        };
        self.debug2.text = @"Blur";
    }
}


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
            cv::Mat grayImg = [OpenCVConversion cvMatGrayFromUIImage:frame];
            if(grayImg.cols == 0)
            {
                NSLog(@"Invalid frame!");
                return;
            }
            cv::resize(grayImg, grayImg, cv::Size(480, 360));

            //TODO CMU: insert the image processing function call here
            //Implement the function in MagicInAir.mm.
            NSInteger f = myFaceDetector->detectFaceInMat(grayImg);

            [self.viewProcessed setImage:[OpenCVConversion UIImageFromCVMat:grayImg]];
            self.debug2.text = [NSString stringWithFormat:@"%d faces", f];
        };
    }
}

- (IBAction)doDetectAR:(id)sender //IBAction is a macro defined to denote variables and methods that can be referred to the Interface builder.
{
    // Not using here, just show how to use static variable
    static int counter= 0;
    static int current_tag = 0;
    static bool done = 0;

    if(self.imgProcType == IMG_PROC_USER_1)
    {
        self.imgProcType = IMG_PROC_DEFAULT;
        self.processFrame = self.defaultProcess;
        self.debug2.text = @"Default";

        [self.spark exitVirtualStickMode];
    }
    else
    {
        // Virtual stick mode is a control interface
        // allow user to progrmmatically control the drone's movement
        [self.spark enterVirtualStickMode];

        // This will change the behavior in the z-axis of the drone
        // If you call change set vertical mode to absolute height, use MoveVxVyYawrateHeight(...) else Otherwise use MoveVxVyYawrateVz(...)

        //Set the height to a height that can view more than two AR tages (potentially three)
        [self.spark setVerticleModeToAbsoluteHeight];

        self.imgProcType = IMG_PROC_USER_1;

        // This is a timer callback function that will run repeatedly when button is clicked
        self.processFrame =
        ^(UIImage *frame){
            counter = counter+1;
            DroneHelper *spark_ptr = [self spark];

            // From here we get the image from the main camera of the drone
            cv::Mat grayImg = [OpenCVConversion cvMatGrayFromUIImage:frame];
            /*
            Ｍat is a matrix that stores the images in OpenCV cmpatible format.
            */

            if(grayImg.cols == 0)
            {
                NSLog(@"Invalid frame!");
                return;
            }
            // Shrink the image for faster processing

            cv::resize(grayImg, grayImg, cv::Size(480, 360));

            // Call detectARTagIDs to get Aruco tag IDs and corner pixel location
            std::vector<std::vector<cv::Point2f> > corners;
            //It is a vector of vectors, where we have as many vectors as there are tags, and each vector is 4-dimensional
            //containing four Point2F objects, where each point2F object is the X-Y coordinte of the corners of a tag.
            std::vector<int> ids = detectARTagIDs(corners,grayImg);
            //detectATTagIDs returns a vector of the IDs detected by the function.

            NSInteger n = ids.size(); //n represents the number of aruco tags that are under the flying image

            auto Number_AR_Tags = 17; //This variable contains the total number of AR tags in teh course

            //----------------LOGIC-----------------Implement your logic to decide where to move the drone----------------

            //---> Below snippet is an example of how you can calculate the center of the marker


            std::vector<cv::Point2f> marker_center;
            std::vector<cv::Point2f> image_vector;
            std::vector<cv::Point2f> motion_vector;
            //cv::Point2f marker_center(0,0);
            //Initialising the marker center to 0, 0

            bool tag_for_takeoff = FALSE;

            #if 0
            for(　auto i　=　0; i　<　n; i++　)
            {
                std::cout << "\nID: " << ids[i]; //Output the ID of the tag whose center is being calculated.
                // This function calculates the average marker center from all the detected tags
                marker_center[i] = VectorAverage(corners[i]);

                // Calculate the image vector relative to the center of the image
                cv::Point2f image_vector[i] = marker_center[i] - cv::Point2f(240,180);
                //Here we align the cener of the aruco tag to the center of the image
                //The image vector is the vector that connects the center of the image with the center of the aruco tag

                // Convert vector from image coordinate to drone navigation coordinate
                cv::Point2f motion_vector[i] = convertImageVectorToMotionVector(image_vector[i]);
            }

            //---> Codes commented below show how to drive the drone to move to the direction such that desired tag is in the center of image frame
            // Find the largest consequnce id
            #endif
            std::vector<cv::Point2f>  corner;
            std::vector<int> ids_tmp(ids);
            std::sort(ids_tmp.begin(),ids_tmp.end());
            for (size_t i = 0; i < n; i++) {
              if(current_tag + 1 == ids_tmp[i])
              {
                current_tag++;
                  break;
                //corner = corners[i];
              }
            }
            //int index = ids.find(current_tag);
            for (size_t i = 0; i < n ; i++) {
                if( current_tag == ids[i])
                    corner = corners[i];
            }
            //corner = corners[index];
            
            
            float error;
            std::cout<<"\n current_tag " <<  current_tag;
            if(!corner.empty())
            {
                cv::Point2f mark_center = VectorAverage(corner);
                error = (mark_center.x - 240.0f) / 480.0f; // get the error and normalize it
                std::cout<<mark_center.x <<" "<<current_tag<< std::endl;
            }
            else {
                error = 0;
            }
        
            
            float const TOL = 0.1;
            float const FORWARD_SPEED = 0.7;
            float const SPEED_WHILE_ROTATION = 0.5;
            //float YAW_RATE = 2 * ( error > 0 ? (-1) : (1) );
            float YAW_RATE = (-25) * ( error > 0 ? (-1) : (1) );

            if (abs(error) > TOL) {
                MoveVxVyYawrateHeight(spark_ptr, SPEED_WHILE_ROTATION , 0 , YAW_RATE , 2.5); // vx,vy,yaw_rate,vz
            }
            else
            {
                MoveVxVyYawrateHeight(spark_ptr, FORWARD_SPEED, 0 ,  0 , 2.5);
            }
            self.debug2.text = [NSString stringWithFormat:@"%d", current_tag];

            //if(current_tag == 12 || current_tag == 11)
            //    MoveVxVyYawrateHeight(spark_ptr, 0, 0 , - 30 , 2.5);

            // If there's no tag detected or reach the end, no motion required
            if(n==0) // Number_AR_Tags == 17
            {
                MoveVxVyYawrateHeight(spark_ptr, 0, 0 ,  - 30 , 2.5);
                //self.debug2.text = [NSString stringWithFormat:@"No tags"];
            }
            if(current_tag == Number_AR_Tags) // Number_AR_Tags == 17
            {
                MoveVxVyYawrateHeight(spark_ptr, 0, 0 ,  0 , 1);
                done = 1;
                
                self.debug2.text = [NSString stringWithFormat:@"finished!"];
            }

            // Move the camera to look down so you can see the tags
            //if (done ==0){
            //    PitchGimbal(spark_ptr,-50.0);
            //}else{
            //    PitchGimbal(spark_ptr,-70.0);
           //  }
            PitchGimbal(spark_ptr,-65.0);

            // Sample function to help you control the drone
            // Such as takeoff and land
            //TakeOff(spark_ptr);
            //Land(spark_ptr);

            // Convert opencv image back to iOS UIImage
            [self.viewProcessed setImage:[OpenCVConversion UIImageFromCVMat:grayImg]];

            // Print some debug text on the App
            
        };
    }
}

/**
 Demo how to move the gimbal to face forward and down.
 */
- (IBAction)onGimbalButtonClicked:(id)sender;
{
    enum {FORWARD=0, DOWN=1};
    static int action = FORWARD;

    if(action == FORWARD)
    {
        if([self.spark setGimbalPitchDegree: 0.0] == FALSE) {
            [self showAlertViewWithTitle:@"Move Gimbal" withMessage:@"Failed"];
        }
        action = DOWN;
    }
    else
    {
        if([self.spark setGimbalPitchDegree: -65.0] == FALSE) {
            [self showAlertViewWithTitle:@"Move Gimbal" withMessage:@"Failed"];
        }
        action = FORWARD;
    }
}

/**
 Demo how to take off and land.
 */
- (IBAction)onTakeoffButtonClicked:(id)sender
{
    enum {TAKEOFF=0, LAND=1};
    static int action = TAKEOFF;

    if(action == TAKEOFF)
    {
        if([self.spark takeoff] == FALSE) {
            [self showAlertViewWithTitle:@"Takeoff" withMessage:@"Failed"];
        }
        else {
            [self showAlertViewWithTitle:@"Takeoff" withMessage:@"Succeeded"];
        }
        [self.btnTakeoffLand setTitle:@"Land" forState:UIControlStateNormal];
        action = LAND;
    }
    else
    {
        if([self.spark land] == FALSE) {
            [self showAlertViewWithTitle:@"Land" withMessage:@"Failed"];
        }
        else {
            [self showAlertViewWithTitle:@"Land" withMessage:@"Succeeded"];
        }

        [self.btnTakeoffLand setTitle:@"Takeoff" forState:UIControlStateNormal];
        action = TAKEOFF;
    }
}

- (IBAction)onDroneMoveClicked:(id)sender
{
    if(self.imgProcType == IMG_PROC_USER_2)
    {
        self.imgProcType = IMG_PROC_DEFAULT;
        self.processFrame = self.defaultProcess;
        self.debug2.text = @"Default";
    }
    else
    {
        self.imgProcType = IMG_PROC_USER_2;
        [self.spark enterVirtualStickMode];
        [self.spark setVerticleModeToVelocity];

        self.processFrame =
        ^(UIImage *frame){
            cv::Mat colorImg = [OpenCVConversion cvMatFromUIImage:frame];
            if(colorImg.cols == 0)
            {
                NSLog(@"Invalid frame!");
                return;
            }
            cv::resize(colorImg, colorImg, cv::Size(480, 360));

            //TODO CMU: insert the image processing function call here
            //Implement the function in MagicInAir.mm.
            sampleMovement(colorImg, self.spark);

            [self.viewProcessed setImage:[OpenCVConversion UIImageFromCVMat:colorImg]];
            //self.debug2.text = [NSString stringWithFormat:@"%d Tags", n];
        };
    }
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
    //fc.yawControlMode = DJIVirtualStickYawControlModeAngle;
    fc.yawControlMode =DJIVirtualStickYawControlModeAngularVelocity;
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
- (IBAction)doAR:(id)sender {
    
    self.debug2.text = @"AR mode";
    
    if(self.imgProcType == IMG_PROC_AR)
    {
        self.imgProcType = IMG_PROC_DEFAULT;
        self.debug2.text = @"Default";
        self.processFrame = self.defaultProcess;
        [self.spark exitVirtualStickMode];
    }
    else
    {
        // Virtual stick mode is a control interface
        // allow user to progrmmatically control the drone's movement
        [self.spark enterVirtualStickMode];
        
        // This will change the behavior in the z-axis of the drone
        // If you call change set vertical mode to absolute height
        // Use MoveVxVyYawrateHeight(...)
        // Otherwise use MoveVxVyYawrateVz(...)
        [self.spark setVerticleModeToAbsoluteHeight];
        
        self.imgProcType = IMG_PROC_AR;
        
        // Here we load the dji logo as the image we would like to overlay as our AR object
        NSString *logoPath = [[NSBundle mainBundle] pathForResource:@"dji_logo" ofType:@"jpg"];
        const char* logoPathInC = [logoPath cStringUsingEncoding:NSUTF8StringEncoding];
        cv::Mat logo = imread(logoPathInC);
        
        // Load the camera parameters from yml file
        // Each camera has different parameters but they should be close to for every DJI Spark
        // If you find the calibration or AR effect is not accurate, please calibrate your Spark
        NSString *path = [[NSBundle mainBundle] pathForResource:@"spark_main_cam_param" ofType:@"yml"];
        const char* pathInC = [path cStringUsingEncoding:NSUTF8StringEncoding];
        cv::FileStorage fs(pathInC, cv::FileStorage::READ);
        int w, h;
        cv::Mat intrinsic, distortion;
        fs["image_width"] >> w;
        fs["image_height"] >> h;
        fs["distortion_coefficients"] >> distortion;
        fs["camera_matrix"] >> intrinsic;
        
        
        // Please measure the marker size in Meter and enter it here
        const float markerSizeMeter = 0.13;
        const float halfSize = markerSizeMeter * 0.5;
        
        // Self-defined tag location in 3D, this is used in step 2 below
        std::vector<cv::Point3f> objPoints{
            cv::Point3f(-halfSize, halfSize, 0),
            cv::Point3f(halfSize, halfSize, 0),
            cv::Point3f(halfSize, -halfSize, 0),
            cv::Point3f(-halfSize, -halfSize, 0)
        };
        
        // AR object points in 3D, this is used in step 4 below
        cv::Mat objectPoints(8, 3, CV_32FC1);
        
        objectPoints.at< float >(0, 0) = -halfSize;
        objectPoints.at< float >(0, 1) = -halfSize;
        objectPoints.at< float >(0, 2) = 0;
        objectPoints.at< float >(1, 0) = halfSize;
        objectPoints.at< float >(1, 1) = -halfSize;
        objectPoints.at< float >(1, 2) = 0;
        objectPoints.at< float >(2, 0) = halfSize;
        objectPoints.at< float >(2, 1) = halfSize;
        objectPoints.at< float >(2, 2) = 0;
        objectPoints.at< float >(3, 0) = -halfSize;
        objectPoints.at< float >(3, 1) = halfSize;
        objectPoints.at< float >(3, 2) = 0;
        
        objectPoints.at< float >(4, 0) = -halfSize;
        objectPoints.at< float >(4, 1) = -halfSize;
        objectPoints.at< float >(4, 2) = markerSizeMeter;
        objectPoints.at< float >(5, 0) = halfSize;
        objectPoints.at< float >(5, 1) = -halfSize;
        objectPoints.at< float >(5, 2) = markerSizeMeter;
        objectPoints.at< float >(6, 0) = halfSize;
        objectPoints.at< float >(6, 1) = halfSize;
        objectPoints.at< float >(6, 2) = markerSizeMeter;
        objectPoints.at< float >(7, 0) = -halfSize;
        objectPoints.at< float >(7, 1) = halfSize;
        objectPoints.at< float >(7, 2) = markerSizeMeter;
        
        
        std::vector<cv::Point2f> logoPoints{
            cv::Point2f(0,0),
            cv::Point2f(0,logo.cols),
            cv::Point2f(logo.rows, logo.cols),
            cv::Point2f(logo.rows,0)
        };
        self.processFrame =
        ^(UIImage *frame){
            // Since this is the bonus part, only high-level instructions will be provided
            // One way you can do this is to:
            // 1. Identify the Aruco tags with corner pixel location
            //    Hint: cv::aruco::detectMarkers(...)
            // 2. For each corner in 3D space, define their 3D locations
            //    The 3D locations you defined here will determine the origin of your coordinate frame
            // 3. Given the 3D locatiions you defined, their 2D pixel location in the image, and camera parameters
            //    You can calculate the 6 DOF of the camera relative to the tag coordinate frame
            //    Hint: cv::solvePnP(...)
            // 4. To put artificial object in the image, you need to create 3D points first and project them into 2D image
            //    With the projected image points, you can draw lines or polygon
            //    Hint: cv::projectPoints(...)
            // 5. To put dji logo on certain location,
            //    you need find the homography between the projected 4 corners and the 4 corners of the logo image
            //    Hint: cv::findHomography(...)
            // 6. Once the homography is found, warp the image with perspective
            //    Hint: cv::warpPerspective(...)
            // 7. Now you have the warped logo image in the right location, just overlay them on top of the camera image
            
            // Load the images
            cv::Mat colorImg = [OpenCVConversion cvMatFromUIImage:frame];
            cv::cvtColor(colorImg, colorImg, CV_RGB2BGR);
            cv::Mat grayImg = [OpenCVConversion cvMatGrayFromUIImage:frame];
            
            // Do your magic!!!
            cv::Ptr<cv::aruco::Dictionary> dictionary = cv::aruco::getPredefinedDictionary(cv::aruco::DICT_6X6_250);
            std::vector<std::vector<cv::Point2f> > corners;
            std::vector<cv::Point2f> projectPoints;
            cv::Mat rvec,tvec;
            
            cv::Mat logoWarped;
            
            
            // Step 1
            std::vector <int> ids;
            cv::aruco::detectMarkers(colorImg, dictionary, corners, ids);
            // Step 2
            
            // Step 3 TODO
            if ((int)corners.size()!= 0){
                cv::solvePnP(objPoints, corners[0], intrinsic, distortion, rvec, tvec);
                // Step 4
                cv::projectPoints(objectPoints, rvec, tvec, intrinsic, distortion, projectPoints);
                cv::line(colorImg, projectPoints[0], projectPoints[1], cv::Scalar(0,255,0),4);
                cv::line(colorImg, projectPoints[1], projectPoints[2], cv::Scalar(0,255,0),4);
                cv::line(colorImg, projectPoints[2], projectPoints[3], cv::Scalar(0,255,0),4);
                cv::line(colorImg, projectPoints[3], projectPoints[0], cv::Scalar(0,255,0),4);
                cv::line(colorImg, projectPoints[4], projectPoints[5], cv::Scalar(255,0,0),4);
                cv::line(colorImg, projectPoints[5], projectPoints[6], cv::Scalar(255,0,0),4);
                cv::line(colorImg, projectPoints[6], projectPoints[7], cv::Scalar(255,0,0),4);
                cv::line(colorImg, projectPoints[7], projectPoints[4], cv::Scalar(255,0,0),4);
                cv::line(colorImg, projectPoints[0], projectPoints[4], cv::Scalar(0,0,255),4);
                cv::line(colorImg, projectPoints[1], projectPoints[5], cv::Scalar(0,0,255),4);
                cv::line(colorImg, projectPoints[2], projectPoints[6], cv::Scalar(0,0,255),4);
                cv::line(colorImg, projectPoints[3], projectPoints[7], cv::Scalar(0,0,255),4);
                
                
                
                
                std::vector<cv::Point2f> targetPoints{
                    projectPoints[4],
                    projectPoints[5],
                    projectPoints[6],
                    projectPoints[7]
                };
                
                // Step 5
                //cv::Mat M = cv::findHomography(objPoints, corners[0]);
                cv::Mat M = cv::findHomography(logoPoints, targetPoints);
                // Step 6
                
                cv::warpPerspective(logo, logoWarped, M, grayImg.size());
                
                // Hint how to overlay warped logo onto the original camera image
                cv::Mat gray,grayInv,src1Final,src2Final;
                cvtColor(logoWarped,gray,CV_BGR2GRAY);
                threshold(gray,gray,0,255,CV_THRESH_BINARY);
                bitwise_not(gray, grayInv);
                colorImg.copyTo(src1Final,grayInv);
                logoWarped.copyTo(src2Final,gray);
                colorImg = src1Final+src2Final;
                
                cv::cvtColor(colorImg, colorImg, CV_BGR2RGB);
            }
            [self.viewProcessed setImage:[OpenCVConversion UIImageFromCVMat:colorImg]];
            
            
        };
        
    }
    
}


@end
