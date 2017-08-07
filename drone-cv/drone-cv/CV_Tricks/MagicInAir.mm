//
//  MagicInAir.cpp
//  drone-cv
//
//  Created by Zhiyuan Li on 7/27/17.
//  Copyright © 2017 dji. All rights reserved.
//
// Some sample codes are borrowed from https://github.com/Duffycola/opencv-ios-demos

#import <Accelerate/Accelerate.h>
#import <CoreFoundation/CoreFoundation.h>

#ifdef __cplusplus

#include "MagicInAir.h"

bool PitchGimbal(DroneHelper *spark,float pitch){
    if([spark setGimbalPitchDegree: pitch] == FALSE) {
        return false;
    }
    return true;
}

bool TakeOff(DroneHelper *spark){
    if([spark takeoff] == FALSE) {
        return false;
    }
    return true;
}

bool Land(DroneHelper *spark){
    if([spark land] == FALSE) {
        return false;
    }
    return true;
}

bool Move(DJIFlightController *flightController, float pitch, float roll, float yaw_rate, float vertical_throttle ){
    //DJIFlightController *flightController = [self fetchFlightController];
    DJIVirtualStickFlightControlData vsFlightCtrlData;
    vsFlightCtrlData.pitch = roll;
    vsFlightCtrlData.roll = pitch;
    vsFlightCtrlData.verticalThrottle = vertical_throttle;
    vsFlightCtrlData.yaw = yaw_rate;
    
    flightController.isVirtualStickAdvancedModeEnabled = YES;
    
    [flightController sendVirtualStickFlightControlData:vsFlightCtrlData withCompletion:^(NSError * _Nullable error) {
     if (error) {
     NSLog(@"Send FlightControl Data Failed %@", error.description);
     }
     }];
    return true;
}


std::vector<int> detectARTagIDs(std::vector<std::vector<cv::Point2f> >& corners, Mat image)
{
    cv::Ptr<cv::aruco::Dictionary> ardict = cv::aruco::getPredefinedDictionary(cv::aruco::DICT_6X6_250);
    //cv::Mat  imageCopy;
    //image.copyTo(imageCopy);
    std::vector<int> ids;
    ;
    cv::aruco::detectMarkers(image, ardict, corners, ids);
    
    int n=ids.size();
    // if at least one marker detected
    if (n > 0)
        cv::aruco::drawDetectedMarkers(image, corners, ids,cv::Scalar( 255, 0, 255 ));
    
    return ids;
}


cv::Point2f VectorAverage(std::vector<cv::Point2f>& corners){
    cv::Point2f average(0,0);
    for(auto i=0; i<corners.size(); i++)
        average = average + corners[i];
    average = average/(float)corners.size();
    return average;
}

cv::Point2f convertImageVectorToMotionVector(cv::Point2f im_vector){
    cv::Point2f p(-im_vector.y,im_vector.x);
    p=p/std::sqrt(p.x*p.x + p.y*p.y);
    p = 0.2*p;
    return p;
}

//+ (void)filterLaplace:(Mat)image withKernelSize:(int)kernel_size;
void filterLaplace(Mat image, int kernel_size)
{
    int scale = 1;
    int delta = 0;
    int ddepth = CV_16S;
    
    GaussianBlur( image, image, cv::Size( kernel_size, kernel_size ), 0, 0 );
    
    const int& width = (int)image.cols;
    const int& height = (int)image.rows;
    const int& bytesPerRow = (int)image.step[0];
    
    // we need to copy because src.data != dst.data must hold with bilateral filter
    unsigned char* data_copy = new unsigned char[max(width,bytesPerRow)*height];
    memcpy(data_copy, image.data, max(width,bytesPerRow)*height);
    
    Mat src(height, width, CV_8UC1, data_copy, bytesPerRow);
    Mat tmp;
    
    Laplacian( src, tmp, ddepth, kernel_size, scale, delta, BORDER_DEFAULT );
    convertScaleAbs( tmp, image );
    
    delete []data_copy;
}

//+ (void)filterBlurHomogeneousAccelerated:(Mat)image withKernelSize:(int)kernel_size;
void filterBlurHomogeneousAccelerated(Mat image, int kernel_size)
{
    // Allocate memory for final result
    const int& width = image.cols;
    const int& height = image.rows;
    const size_t& bytesPerRow = image.step[0];
    
    Pixel_8 *inData = (Pixel_8 *)malloc( bytesPerRow * height );
    memcpy(inData, image.data, bytesPerRow * height);
    
    // Create kernel
    int16_t *kernel = (int16_t *)malloc(kernel_size * kernel_size * sizeof(int16_t));
    int16_t *tempKernel = kernel;
    
    for (int i = 0; i < (kernel_size*kernel_size); i++) {
        *tempKernel++ = 1;
    }
    
    vImage_Buffer image_in = { inData, static_cast<vImagePixelCount>(height), static_cast<vImagePixelCount>(width), bytesPerRow };
    vImage_Buffer image_out = { image.data, static_cast<vImagePixelCount>(height), static_cast<vImagePixelCount>(width), bytesPerRow };
    
    // Convolve using Accelerate framework
    vImageConvolve_Planar8(&image_in,
                           &image_out,
                           NULL,
                           0,
                           0,
                           kernel,
                           kernel_size,
                           kernel_size,
                           kernel_size*kernel_size,
                           0,
                           kvImageBackgroundColorFill);
    
    free(inData);
    free(kernel);
}

int detectARTag(Mat image)
{
    cv::Ptr<cv::aruco::Dictionary> ardict = cv::aruco::getPredefinedDictionary(cv::aruco::DICT_6X6_250);
    //cv::Mat  imageCopy;
    //image.copyTo(imageCopy);
    std::vector<int> ids;
    std::vector<std::vector<cv::Point2f> > corners;
    cv::aruco::detectMarkers(image, ardict, corners, ids);
    
    int n=ids.size();
    // if at least one marker detected
    if (n > 0)
        cv::aruco::drawDetectedMarkers(image, corners, ids,cv::Scalar( 255, 0, 255 ));
    
    return n;
}

void sampleFeedback(Mat image, DroneHelper * drone)
{
/**
 * Remember this function is called every time
 * a frame is available. So don't do long loop here.
 */
    cv::cvtColor(image, image, COLOR_BGR2YUV);
    
    cv::extractChannel(image, image, 0);
    
    DJIVirtualStickFlightControlData ctrl;
    ctrl.pitch = 0.1;
    ctrl.roll = 0.0;
    ctrl.yaw  = 0.0;
    ctrl.verticalThrottle = 0.0;
    [drone sendMovementCommand:ctrl];
}


# pragma mark Face detection using CV
SimpleFaceDetector::SimpleFaceDetector(std::string filename)
{
    loadCascades(filename);
}

SimpleFaceDetector::~SimpleFaceDetector()
{
    if(face_cascade)
    {
        delete face_cascade;
    }
}

int SimpleFaceDetector::detectFaceInMat(cv::Mat &grayMat)
{
    std::vector<cv::Rect> faces;
    
    // haar detect
    float haar_scale = 1.15;
    int haar_minNeighbors = 3;
    int haar_flags = 0 | CV_HAAR_SCALE_IMAGE | CV_HAAR_DO_CANNY_PRUNING;
    cv::Size haar_minSize = cvSize(60, 60);
    
    face_cascade->detectMultiScale(grayMat, faces, haar_scale,
                                   haar_minNeighbors, haar_flags, haar_minSize );
    
    for( int i = 0; i < faces.size(); i++ )
    {
        cv::Point center( faces[i].x + faces[i].width*0.5, faces[i].y + faces[i].height*0.5 );
        cv::ellipse( grayMat, center, cv::Size( faces[i].width*0.5, faces[i].height*0.5), 0, 0, 360, cv::Scalar( 255, 0, 255 ), 4, 8, 0 );
    }
    NSLog(@"%d faces detected", (int)faces.size());
    return ((int)faces.size());
}

void SimpleFaceDetector::loadCascades(std::string filename)
{
    if(NULL != face_cascade)
    {
        delete face_cascade;
    }
    face_cascade = new cv::CascadeClassifier();
    //CFBundleRef mainBundle = CFBundleGetMainBundle();
    
    NSString *fname = [NSString stringWithCString:filename.c_str()
                                         encoding:[NSString defaultCStringEncoding]];
    
    NSString *real_path = [[NSBundle mainBundle] pathForResource:fname ofType:@"xml"];
    
    if (real_path != nil && !face_cascade->load([real_path UTF8String]))
    {
        NSLog(@"Unable to load cascade file");
    }
    else
    {
        NSLog(@"------Loaded cascade file");
    }
}


#endif
