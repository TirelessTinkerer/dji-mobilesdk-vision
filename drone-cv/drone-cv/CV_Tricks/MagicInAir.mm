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

bool Move(DJIFlightController *flightController, float vx, float vy, float yaw_rate, float vz ){
    //DJIFlightController *flightController = [self fetchFlightController];
    DJIVirtualStickFlightControlData vsFlightCtrlData;
    vsFlightCtrlData.pitch = vy;
    vsFlightCtrlData.roll = vx;
    vsFlightCtrlData.verticalThrottle = vz;
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

bool goal_achieved3d(cv::Point3f target_pos, cv::Point3f marker_pos){
    float distance_threshold = 0.2;
    cv::Point3f p = target_pos - marker_pos;
    float dot_product = p.dot(p);
    if(dot_product < (distance_threshold*distance_threshold))
        return true;
    return false;
}

bool goal_achieved_yaw(float yaw){
    float yaw_threshold = 3.5;
    if(std::abs(yaw) < yaw_threshold)
        return true;
    return false;
}


bool goal_achieved(cv::Point2f point)
{
    int MINIMUM_DIST_PIXELS = 1000;
    cv::Point2f image_vector = point - cv::Point2f(240,180);
    return (image_vector.x*image_vector.x + image_vector.y*image_vector.y) < MINIMUM_DIST_PIXELS;
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
    float k=0.004;
    p = k*p;
    float norm = std::sqrt(p.x*p.x + p.y*p.y);
    if(norm>0.5)
        p = 0.5*p/norm;
    return p;
}

/*cv::Point2f convertFaceImageVectorToMotionVector(cv::Point2f im_vector){
    cv::Point2f p(0,-im_vector.x);
    float k=0.004;
    p = k*p;
    float norm = std::sqrt(p.x*p.x + p.y*p.y);
    if(norm>0.5)
        p = 0.5*p/norm;
    return p;
}*/


cv::Point3f TagPos2Control(cv::Point3f tag_pos, cv::Point3f target_pos, float yaw, float &yaw_rate_op){
    
    cv::Point3f p = tag_pos - target_pos;
    float k_pos=0.3;
    p = k_pos*p;
    float norm = std::sqrt(p.x*p.x + p.y*p.y + p.z*p.z);
    if(norm>0.4)
        p = 0.4*p/norm;
    
    float k_yaw = 0.3;
    yaw_rate_op = k_yaw*yaw;
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

cv::Point3f TagFrame2DroneFrame(cv::Point3f tag_pos){
    cv::Point3f drone_pos;
    drone_pos.x = tag_pos.z;
    drone_pos.y = tag_pos.x;
    drone_pos.z = -tag_pos.y;
    return drone_pos;
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
void MarkerPose(std::vector<Point2f> detectedCorners, cv::Point3f &tag_frame, cv::Vec3d &rpy){
    cv::Mat rvec(3,3,CV_32F);
    cv::Mat tvec(3,1,CV_32F);
    std::vector<cv::Point3f> objectPoints;
    cv::Point3f p1,p2,p3,p4;
    p1.x = 0;   p1.y=0; p1.z=0;
    p2.x = .10;  p2.y=0; p2.z=0;
    p3.x = .10;  p3.y=.10;p3.z=0;
    p4.x = 0;   p4.y=.10;p4.z=0;
    objectPoints.push_back(p1);objectPoints.push_back(p2);objectPoints.push_back(p3);objectPoints.push_back(p4);
    //std::vector<cv::Point2f> detectedCorners = corners[0];
    cv::Mat cameraMatrix;
    cv::Vec4f distCoeff;
    cameraMatrix = cv::Mat::zeros(3, 3, CV_32F);
    cameraMatrix.at<float>(0,0) = 633.4373;
    cameraMatrix.at<float>(0,2) = 328.3448;
    cameraMatrix.at<float>(1,1) = 636.4243;
    cameraMatrix.at<float>(1,2) = 186.8022;
    cameraMatrix.at<float>(2,2) = 1.0;
    
    distCoeff.zeros();
    
    //                std::cout<<"corners:"<<detectedCorners.size()<<" Object:"<<objectPoints.size()<<cameraMatrix;
    cv::solvePnP(objectPoints,detectedCorners,cameraMatrix,distCoeff,rvec,tvec);
    cv::transpose(tvec, tvec);
    cv::Rodrigues(rvec, rvec);
    cv::Mat u,l;
    rpy = cv::RQDecomp3x3(rvec, u, l);
    //std::cout<<"\nTvec: "<<tvec;
    //std::cout<<"\nRPY: "<<rpy;
    tag_frame; tag_frame.x = tvec.at<double>(0);
    tag_frame.y = tvec.at<double>(1);
    tag_frame.z = tvec.at<double>(2);
}

bool CenterOnTag(DJIFlightController *flightController , std::vector<std::vector<cv::Point2f> > &corners, std::vector<int>& detected_marker_IDs, int query_id, float height){
    //<TESTING INTRISICS>
    int n = detected_marker_IDs.size();
    bool found_goal_id = false;
    int goal_index_detect = 0;
    for(auto i=0; i<n; i++)
    {
        if(detected_marker_IDs[i]==query_id){
            found_goal_id = true;
            goal_index_detect = i;
            break;
        }
    }
    if(n>0){
        std::cout<<"ID::"<<detected_marker_IDs[0];
    }
    if(found_goal_id)
    {
        cv::Point3f tag_frame;
        cv::Vec3d rpy;
        MarkerPose(corners[goal_index_detect], tag_frame, rpy);
        
        //Trying to center
        cv::Point3f tag_pos = TagFrame2DroneFrame(tag_frame);
        cv::Point3f target_pos(1.3,0,0);
        float tag_yaw = rpy[1];
        float yaw_rate_output;
        cv::Point3f motion_vector = TagPos2Control(tag_pos, target_pos, tag_yaw, yaw_rate_output);
        std::cout<< "\n Tag::"<<tag_frame.x<<"::"<<tag_frame.y<<"::"<<tag_frame.z<<"\n";
        std::cout<<"Transformed Tag::"<<tag_pos.x<<"::"<<tag_pos.y<<"::"<<tag_pos.z<<"::"<<tag_yaw<<"\n";
        std::cout<<"Motion Vector::"<<motion_vector.x<<"::"<<motion_vector.y<<"::"<<yaw_rate_output<<"\n";
        //int MINIMUM_DIST_PIXELS = 900;
        float yaw = 0;
        if(goal_achieved3d(target_pos, tag_pos) && goal_achieved_yaw(tag_yaw)){
            return true;
        }
        else{
            Move(flightController, motion_vector.x, motion_vector.y, yaw_rate_output, height);
        }
    }
    else{
        Move(flightController, 0, 0, 15, height);
    }
    return false;
}

bool detectTagID(std::vector<int>& detected_marker_IDs, int query_id)
{  bool found_goal_id = false;
    int goal_index_detect = 0;
    for(auto i=0; i<detected_marker_IDs.size(); i++)
    {
        if(detected_marker_IDs[i]==query_id){
            found_goal_id = true;
            goal_index_detect = i;
            break;
        }
    }
    return found_goal_id;
}


cv::Mat drawRectangles(cv::Mat im, std::vector<int>& detected_ids){
    im  = Scalar(125);
    int x_offset = 178;
    int y_offset = 40;
    int rect_size = 80;
    Scalar valid_color(255);
    Scalar invalid_color(50);
    Scalar black(0);
    int rect_space_x = 15;
    int rect_space_y = 30;
    cv::Point p1(0,0);
    cv::Point p2(20,40);
    int index=0;
    std::string test;
    cv::putText(im,test, p2, cv::FONT_HERSHEY_TRIPLEX, 1, Scalar(0));
    
    for(int j=0; j<3; j++){
        for(int i=0; i<3; i++){
            //detected_ids[index];
            index = index+1;
            p1.x = x_offset + i*(rect_size+rect_space_x);
            p1.y = y_offset + j*(rect_size+rect_space_y);
            
            p2.x = x_offset + i*(rect_size+rect_space_x)+rect_size;
            p2.y = y_offset + j*(rect_size+rect_space_y)+rect_size*0.8;
            
            cv::rectangle(im, p1, p2, valid_color, -1);
            cv::rectangle(im, p1, p2, black, 1.5);
        }
    }

    return im;
}
#endif
