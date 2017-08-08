//
//  MagicInAir.h
//  drone-cv
//
//  Created by Zhiyuan Li on 7/27/17.
//  Copyright © 2017 dji. All rights reserved.
//

#ifndef MagicInAir_h
#define MagicInAir_h

#import "DroneHelper.h"

#ifdef __cplusplus
#include <opencv2/imgproc/imgproc.hpp>
#include <opencv2/objdetect/objdetect.hpp>
#include <opencv2/core/core.hpp>
#include <opencv2/aruco.hpp>
#include <list>

using namespace std;
using namespace cv;

bool PitchGimbal(DroneHelper *spark,float pitch);
bool TakeOff(DroneHelper *spark);
bool Land(DroneHelper *spark);


bool MoveVxVyYawrateVz(DJIFlightController *flightController, float V_forward, float V_right, float yaw_rate, float V_up );

bool MoveVxVyYawrateHeight(DJIFlightController *flightController, float V_forward, float V_right, float yaw_rate, float height );

std::vector<int> detectARTagIDs(std::vector<std::vector<cv::Point2f> >& corners,Mat image);
cv::Point2f VectorAverage(std::vector<cv::Point2f>& corners);
cv::Point2f convertImageVectorToMotionVector(cv::Point2f im_vector);



void filterLaplace(Mat image, int kernel_size);
void filterBlurHomogeneousAccelerated(Mat image, int kernel_size);
int  detectARTag(Mat image);
void sampleMovement(Mat image, DroneHelper * drone);

class SimpleFaceDetector
{
private:
    cv::CascadeClassifier* face_cascade;
    void loadCascades(std::string filename);
public:
    SimpleFaceDetector(std::string filename);
    ~SimpleFaceDetector();
    int detectFaceInMat(cv::Mat &grayMat);
};
#endif

#endif /* MagicInAir_h */
