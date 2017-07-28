//
//  MagicInAir.cpp
//  drone-cv
//
//  Created by Zhiyuan Li on 7/27/17.
//  Copyright © 2017 dji. All rights reserved.
//
// Some sample codes are borrowed from https://github.com/Duffycola/opencv-ios-demos

#import <Accelerate/Accelerate.h>

#ifdef __cplusplus

#include "MagicInAir.h"

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
    
    if (!filename.empty() && !face_cascade->load(filename))
    {
        NSLog(@"Unable to load cascade file");
    }
    else
    {
        NSLog(@"------Loaded cascade file");
    }
}


#endif
