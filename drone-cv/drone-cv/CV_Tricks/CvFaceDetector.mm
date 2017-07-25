//
//  CvFaceDetector.m
//  FaceDetectVideo 
//
//  Created by Eduard Feicho on 07.06.12.
//  Copyright (c) 2012 Eduard Feicho. All rights reserved.
//

#import "CvFaceDetector.h"

@interface CvFaceDetector(PrivateMethods)
- (cv::CascadeClassifier*)loadCascade:(NSString*)filename;
@end


@implementation CvFaceDetector

#pragma mark - Properties

@synthesize detectEyes;

#pragma mark - Constructor

- (id)init;
{
	self = [super init];
	if (self) {
#ifdef __cplusplus
		face_cascade = NULL;
		eyes_cascade = NULL;
#endif
		self.detectEyes = YES;
		
		[self loadCascades];
	}
	return self;
}

- (void)dealloc;
{
#ifdef __cplusplus
	if (face_cascade != NULL) delete face_cascade;
	if (eyes_cascade != NULL) delete eyes_cascade;
#endif
}

#pragma mark - Other Methods

- (void)loadCascades;
{
	face_cascade = [self loadCascade:@"lbpcascade_frontalface"];
	//eyes_cascade = [self loadCascade:@"haarcascade_eye"];
    //face_cascade = [self loadCascade:@"haarcascade_frontalface_alt"];
}


- (cv::CascadeClassifier*)loadCascade:(NSString*)filename;
{
	NSString *real_path = [[NSBundle mainBundle] pathForResource:filename ofType:@"xml"];
	cv::CascadeClassifier* cascade = new cv::CascadeClassifier();
	
	if (real_path != nil && !cascade->load([real_path UTF8String])) {
		NSLog(@"Unable to load cascade file %@.xml", filename);
	} else {
		NSLog(@"------Loaded cascade file %@.xml", filename);
	}
	return cascade;
}

- (NSInteger)detectFacesInMat:(Mat&)grayMat;
{
    std::vector<cv::Rect> faces;
    
    // haar detect
    float haar_scale = 1.15;
    int haar_minNeighbors = 3;
    int haar_flags = 0 | CV_HAAR_SCALE_IMAGE | CV_HAAR_DO_CANNY_PRUNING;
    cv::Size haar_minSize = cvSize(60, 60);
    
    face_cascade->detectMultiScale(grayMat, faces, haar_scale,
                                   haar_minNeighbors, haar_flags, haar_minSize );
    
    for( int i = 0; i < faces.size(); i++ ) {
        cv::Point center( faces[i].x + faces[i].width*0.5, faces[i].y + faces[i].height*0.5 );
        cv::ellipse( grayMat, center, cv::Size( faces[i].width*0.5, faces[i].height*0.5), 0, 0, 360, cv::Scalar( 255, 0, 255 ), 4, 8, 0 );
    }
    NSLog(@"%d faces detected", (int)faces.size());
    return (faces.size());
}


@end
