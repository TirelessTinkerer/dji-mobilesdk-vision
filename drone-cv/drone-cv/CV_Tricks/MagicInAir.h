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
bool Move(DJIFlightController *flightController, float vx, float vy, float yaw_rate, float vz );
bool GoToHeight(DJIFlightController *flightController, float vx, float vy, float yaw_rate, float vz);
std::vector<int> detectARTagIDs(std::vector<std::vector<cv::Point2f> >& corners,Mat image);
cv::Point2f VectorAverage(std::vector<cv::Point2f>& corners);
cv::Point2f convertImageVectorToMotionVector(cv::Point2f im_vector);
cv::Point3f TagFrame2DroneFrame(cv::Point3f tag_pos);
cv::Point3f TagPos2Control(cv::Point3f tag_pos, cv::Point3f target_pos, float yaw, float &yaw_rate_op);
void MarkerPose(std::vector<Point2f> detectedCorners, cv::Point3f &tag_frame, cv::Vec3d &rpy);
bool CenterOnTag(DJIFlightController *flightController , std::vector<std::vector<cv::Point2f> > &corners, std::vector<int>& detected_marker_IDs, int query_id, float height);
//int MINIMUM_DIST_PIXELS = 900;
bool goal_achieved_yaw(float yaw);
bool goal_achieved3d(cv::Point3f target_pos, cv::Point3f marker_pos);
//static std::vector<bool> is_past_waypt(20);
bool goal_achieved(cv::Point2f point);
void filterLaplace(Mat image, int kernel_size);
void filterBlurHomogeneousAccelerated(Mat image, int kernel_size);
int  detectARTag(Mat image);
void sampleFeedback(Mat image, DroneHelper * drone);
cv::Mat drawRectangles(cv::Mat im, std::vector<int>& detected_ids);
bool detectTagID(std::vector<int>& detected_marker_IDs, int query_id);
cv::Mat drawRectangles(cv::Mat im, std::vector<int>& inventory_list, std::vector<int>& prev_inventory_list);

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
