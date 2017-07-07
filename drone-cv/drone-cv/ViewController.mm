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


#define WeakRef(__obj) __weak typeof(self) __obj = self
#define WeakReturn(__obj) if(__obj ==nil)return;

@interface ViewController()<DJIVideoFeedListener, DJISDKManagerDelegate, DJICameraDelegate, DJIBaseProductDelegate>
@property (weak, nonatomic) IBOutlet UIView *fpvPreview;
@property (weak, nonatomic) IBOutlet UIImageView *imgView;
@property (strong, nonatomic) UIImage *myImage;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self registerApp];
    self.imgView.contentMode = UIViewContentModeScaleAspectFit;
    [self.imgView setBackgroundColor:[UIColor blackColor]];
    self.myImage = [UIImage imageNamed:@"test_site.png"];
    [self.imgView setImage:self.myImage];
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
        
        [DJISDKManager startConnectionToProduct];
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
    //self.currentRecordTimeLabel.text = @"Connected, setup previewer";
    [[VideoPreviewer instance] setView:self.fpvPreview];
    [[DJISDKManager videoFeeder].primaryVideoFeed addListener:self withQueue:nil];
    [[VideoPreviewer instance] start];
    
    //[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(takeSnapshot) userInfo:nil repeats:YES];
}

// Called by productDisconnected
- (void) resetVideoPreview
{
    //self.currentRecordTimeLabel.text = @"Disconnected, distroy previewer";
    [[VideoPreviewer instance] unSetView];
    [[DJISDKManager videoFeeder].primaryVideoFeed removeListener:self];
}

#pragma mark - DJIVideoFeedListener
-(void)videoFeed:(DJIVideoFeed *)videoFeed didUpdateVideoData:(NSData *)videoData {
    [[VideoPreviewer instance] push:(uint8_t *)videoData.bytes length:(int)videoData.length];
}
//
//- (void)takeSnapshot
//{
//    UIView *snapshot = [self.fpvPreviewView snapshotViewAfterScreenUpdates:YES];
//    snapshot.tag = 100001;
//    
//    if ([self.frameView viewWithTag:100001]) {
//        [[self.frameView viewWithTag:100001] removeFromSuperview];
//    }
//    
//    [self.frameView addSubview:snapshot];
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
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC1); // 8 bits per component, 1 channels
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to data
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

@end
