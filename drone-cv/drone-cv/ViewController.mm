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
#import "CvConvolutionController.h"


#define WeakRef(__obj) __weak typeof(self) __obj = self
#define WeakReturn(__obj) if(__obj ==nil)return;

@interface ViewController()<DJIVideoFeedListener, DJISDKManagerDelegate, DJICameraDelegate, DJIBaseProductDelegate>
@property (weak, nonatomic) IBOutlet UIView *fpvPreview;
@property (weak, nonatomic) IBOutlet UIImageView *imgView;
@property (strong, nonatomic) UIImage *myImage;
@property (weak, nonatomic) IBOutlet UILabel *debugLabel;
@property (weak, nonatomic) IBOutlet UILabel *debug2;
@property (assign, nonatomic) NSInteger counter;
@property (weak, nonatomic) NSTimer *myTimer;
@property (nonatomic, copy, nullable) void (^processFrame)(UIImage *frame);

@property (nonatomic, copy) void (^defaultProcess)(UIImage *frame);
@property (atomic) enum Filter_Mode filterType;

@property (weak, nonatomic) IBOutlet UIButton *laplaceFilter;
@property (weak, nonatomic) IBOutlet UIButton *gaussBlue;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self registerApp];
    self.imgView.contentMode = UIViewContentModeScaleAspectFit;
    [self.imgView setBackgroundColor:[UIColor redColor]];
    self.myImage = [UIImage imageNamed:@"mavic.jpg"];
    [self.imgView setImage:self.myImage];
    self.myTimer=nil;
    
    self.defaultProcess = ^(UIImage *frame){
        cv::Mat colorImg, gray;
        cv::Mat dst, detected_edges;
        
        cv::resize([self cvMatFromUIImage:frame], colorImg, cv::Size(480, 270));
        cv::cvtColor(colorImg, gray, CV_BGR2GRAY);
        cv::blur(gray,gray, cv::Size(3,3));
        cv::Canny(gray, detected_edges, 40, 120, 3);
        dst = cv::Scalar::all(0);
        colorImg.copyTo(dst, detected_edges);
        [self.imgView setImage:[self UIImageFromCVMat:dst]];
    };
    
    self.filterType = FILTERMODE_DEFAULT;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    DJICamera *camera = [self fetchCamera];
    if (camera && camera.delegate == self) {
        [camera setDelegate:nil];
    }
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
        message = @"Register App Failed! Please enter your App Key and check the network.";
    }else
    {
        NSLog(@"registerAppSuccess");
        
     //   [DJISDKManager startConnectionToProduct];
//        [DJISDKManager enableBridgeModeWithBridgeAppIP:@"10.128.129.54"];
        [DJISDKManager enableBridgeModeWithBridgeAppIP:@"192.168.0.107"];
    }
    
    [self showAlertViewWithTitle:@"Register App" withMessage:message];
}
/////////////////////// End App Registration Related functions

/*---------------------- The following function deals with fpv view----------*/
- (void)productConnected:(DJIBaseProduct *)product
{
    if(product){
        [product setDelegate:self];
        DJICamera * camera = [self fetchCamera];
        if (camera != nil) {
            camera.delegate = self;
        }
        [self setupVideoPreviewer]; // Implemented below
    }
}

- (void) productDisconnected
{
    DJICamera *camera = [self fetchCamera];
    if(camera && camera.delegate == self) {
        [camera setDelegate:nil];
    }
    [self resetVideoPreview]; // Implemented below
}

- (DJICamera*) fetchCamera
{
    if(![DJISDKManager product]){
        return nil;
    }
    
    if([[DJISDKManager product] isKindOfClass:[DJIAircraft class]]){
        return ((DJIAircraft*)[DJISDKManager product]).camera;
    } else if([[DJISDKManager product] isKindOfClass:[DJIHandheld class]]) {
        return ((DJIHandheld*)[DJISDKManager product]).camera;
    }
    
    return nil;
}

// Called by productConnected
- (void) setupVideoPreviewer
{
    self.debugLabel.text = @"Connected!";
    self.debug2.text = @"Init-ed";
    [[VideoPreviewer instance] setView:self.fpvPreview];
    [[DJISDKManager videoFeeder].primaryVideoFeed addListener:self withQueue:nil];
    [[VideoPreviewer instance] start];
    
    self.myTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(timerCallback) userInfo:nil repeats:YES];
    self.counter = 0;
    
    // This is where you define your image processing method
    self.processFrame = self.defaultProcess;
}

// Called by productDisconnected
- (void) resetVideoPreview
{
    self.debugLabel.text = @"Disconnected!";
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
//
//-(void) takeSnapshot3
//{
//    [[VideoPreviewer instance] snapshotPreview:^(UIImage *snapshot) {
//       
//        cv::Mat gray;
//        cv::Mat dst, detected_edges;
//
//        cv::Mat colorImg = [self cvMatFromUIImage:snapshot];
//        cv::cvtColor(colorImg, gray, CV_BGR2GRAY);
////        blur(gray,detected_edges, cv::Size(3,3));
//        cv::Canny(gray, detected_edges, 40, 120, 3);
//        dst = cv::Scalar::all(0);
//        colorImg.copyTo(dst, detected_edges);
//        [self.imgView setImage:[self UIImageFromCVMat:dst]];
//    }];
//}


#pragma mark - OpenCV helpers
- (cv::Mat)cvMatFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}

- (cv::Mat)cvMatGrayFromUIImage:(UIImage *)image
{
    cv::Mat cvMat = [self cvMatFromUIImage:image];
    cv::Mat grayMat;
    
    if (cvMat.channels() == 1) {
        grayMat = cvMat;
    } else{
        grayMat = cv :: Mat(cvMat.rows,cvMat.cols, CV_8UC1);
        cv::cvtColor(cvMat, grayMat, CV_BGR2GRAY);
    }
    return grayMat;
}

-(UIImage *)UIImageFromCVMat:(cv::Mat)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}

// Filter Buttons
- (IBAction)doLaplace:(id)sender;
{
    if(self.filterType == FILTERMODE_LAPLACIAN)
    {
        self.filterType = FILTERMODE_DEFAULT;
        self.processFrame = self.defaultProcess;
        self.debug2.text = @"Default";
    }
    else
    {
        self.filterType = FILTERMODE_LAPLACIAN;
        self.processFrame =
        ^(UIImage *frame){
            cv::Mat colorImg;
            cv::resize([self cvMatGrayFromUIImage:frame], colorImg, cv::Size(480, 270));

            [CvConvolutionController filterLaplace:colorImg withKernelSize:3];
            
            [self.imgView setImage:[self UIImageFromCVMat:colorImg]];
        };
        self.debug2.text = @"Laplace";
    }
}

- (IBAction)doGaussian:(id)sender;
{
    if(self.filterType == FILTERMODE_BLUR_GAUSSIAN)
    {
        self.filterType = FILTERMODE_DEFAULT;
        self.processFrame = self.defaultProcess;
        self.debug2.text = @"Default";
    }
    else
    {
        self.filterType = FILTERMODE_BLUR_GAUSSIAN;
        self.processFrame =
        ^(UIImage *frame){
            cv::Mat colorImg;
            cv::resize([self cvMatGrayFromUIImage:frame], colorImg, cv::Size(480, 270));
            
            [CvConvolutionController filterBlurHomogeneousAccelerated:colorImg withKernelSize:21];
            
            [self.imgView setImage:[self UIImageFromCVMat:colorImg]];
        };
        self.debug2.text = @"Laplace";
    }
}

- (IBAction)doDetect:(id)sender;
{
    
}
@end
