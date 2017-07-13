//
//  CvConvolutionController.h
//  VideoConvolution
//
//  Created by Eduard Feicho on 13.06.12.
//  Copyright (c) 2012 Eduard Feicho. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>


#ifdef __cplusplus

#include <opencv2/imgproc/imgproc.hpp>
#include <opencv2/core/core.hpp>
using namespace cv;

#include <list>
using namespace std;

#endif




@interface CvConvolutionController : NSObject
{
    
}

#ifdef __cplusplus
+ (void)filterBlurHomogeneous:(Mat)image withKernelSize:(int)kernel_size;
+ (void)filterBlurGaussian:(Mat)image withKernelSize:(int)kernel_size;
+ (void)filterBlurMedian:(Mat)image withKernelSize:(int)kernel_size;
+ (void)filterBlurBilateral:(Mat)image withKernelSize:(int)kernel_size;
+ (void)filterLaplace:(Mat)image withKernelSize:(int)kernel_size;
+ (void)filterSobel:(Mat)image withKernelSize:(int)kernel_size;
+ (void)filterCanny:(Mat)image withKernelSize:(int)kernel_size andLowThreshold:(int)lowThreshold;

+ (void)filterBlurHomogeneousAccelerated:(Mat)image withKernelSize:(int)kernel_size;
+ (void)filterBlurGaussianAccelerated:(Mat)image withKernelSize:(int)kernel_size;
#endif


@end
