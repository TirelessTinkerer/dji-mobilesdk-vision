//
//  CvFaceDetector.h
//  FaceDetectVideo 
//
//  Created by Eduard Feicho on 07.06.12.
//  Copyright (c) 2012 Eduard Feicho. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>


#ifdef __cplusplus

#include <opencv2/objdetect/objdetect.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#include <opencv2/core/core.hpp>
using namespace cv;

#include <list>
using namespace std;

#endif





@interface CvFaceDetector : NSObject
{
#ifdef __cplusplus
	cv::CascadeClassifier* eyes_cascade;
	cv::CascadeClassifier* face_cascade;
#else
	void* eyes_cascade;
	void* face_cascade;
#endif
	
	BOOL detectEyes;
};

@property (nonatomic, assign) BOOL detectEyes;


- (void)loadCascades;

#ifdef __cplusplus
- (NSInteger)detectFacesInMat:(cv::Mat&)grayMat;
#endif


@end
