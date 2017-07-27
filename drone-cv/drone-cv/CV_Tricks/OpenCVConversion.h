//
//  OpenCVConversion.h
//  drone-cv
//
//  Created by Zhiyuan Li on 7/27/17.
//  Copyright © 2017 dji. All rights reserved.
//

#ifndef OpenCVConversion_h
#define OpenCVConversion_h

@interface OpenCVConversion : NSObject

+ (cv::Mat)cvMatFromUIImage:(UIImage *)image;//convert UIImage to cv::Mat
+ (cv::Mat)cvMatGrayFromUIImage:(UIImage *)image;//convert UIImage to gray cv::Mat
+ (UIImage *)UIImageFromCVMat:(cv::Mat)cvMat;//convert cv::Mat to UIImage

@end

#endif /* OpenCVConversion_h */
