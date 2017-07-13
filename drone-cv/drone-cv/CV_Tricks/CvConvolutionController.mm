//
//  CvConvolutionController.m
//  VideoConvolution
//
//  Created by Eduard Feicho on 13.06.12.
//  Copyright (c) 2012 Eduard Feicho. All rights reserved.
//

#import "CvConvolutionController.h"

#include <opencv2/core/core.hpp>


@implementation CvConvolutionController


#ifdef __cplusplus

+ (void)filterBlurHomogeneous:(Mat)image withKernelSize:(int)kernel_size;
{
	// process pixel buffer before rendering
	cv::Mat dst = image;
	cv::blur( image, dst, cv::Size( kernel_size, kernel_size ), cv::Point(-1,-1) );
}


 
+ (void)filterBlurGaussian:(Mat)image withKernelSize:(int)kernel_size;
{
	cv::Mat dst = image;
	GaussianBlur( image, dst, cv::Size( kernel_size, kernel_size ), 0, 0 );
}


+ (void)filterBlurMedian:(Mat)image withKernelSize:(int)kernel_size;
{
	cv::Mat dst = image;
	cv::medianBlur ( image, dst, kernel_size );
}



+ (void)filterBlurBilateral:(Mat)image withKernelSize:(int)kernel_size;
{
	const int& width = (int)image.cols;
	const int& height = (int)image.rows;
	const int& bytesPerRow = (int)image.step[0];
	
	// we need to copy because src.data != dst.data must hold with bilateral filter
	unsigned char* data_copy = new unsigned char[max(width,bytesPerRow)*height];
	memcpy(data_copy, image.data, max(width,bytesPerRow)*height);
		
	cv::Mat src(height, width, CV_8UC1, data_copy, bytesPerRow);
	
	bilateralFilter ( src, image, kernel_size, kernel_size*2, kernel_size/2 );
	
	delete data_copy;
}



// http://docs.opencv.org/doc/tutorials/imgproc/imgtrans/laplace_operator/laplace_operator.html#laplace-operator
+ (void)filterLaplace:(Mat)image withKernelSize:(int)kernel_size;
{
	int scale = 1;
	int delta = 0;
	int ddepth = CV_16S;
	
	[CvConvolutionController filterBlurGaussian:image withKernelSize:3];
	
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
	
	delete data_copy;
}



// http://docs.opencv.org/doc/tutorials/imgproc/imgtrans/sobel_derivatives/sobel_derivatives.html#sobel-derivatives
+ (void)filterSobel:(Mat)image withKernelSize:(int)kernel_size;
{
	int scale = 1;
	int delta = 0;
	int ddepth = CV_16S;
	
	[CvConvolutionController filterBlurGaussian:image withKernelSize:kernel_size];
	
	const int& width = (int)image.cols;
	const int& height = (int)image.rows;
	const int& bytesPerRow = (int)image.step[0];
	
	// we need to copy because src.data != dst.data must hold with bilateral filter
	unsigned char* data_copy = new unsigned char[max(width,bytesPerRow)*height];
	memcpy(data_copy, image.data, max(width,bytesPerRow)*height);
	
	Mat src(height, width, CV_8UC1, data_copy, bytesPerRow);
	Mat tmp;
	
	Mat grad_x, grad_y;
	Mat abs_grad_x, abs_grad_y;
	
	/// Gradient X
	//Scharr( src, grad_x, ddepth, 1, 0, scale, delta, BORDER_DEFAULT );
	Sobel( src, grad_x, ddepth, 1, 0, kernel_size, scale, delta, BORDER_DEFAULT );
	convertScaleAbs( grad_x, abs_grad_x );
	/// Gradient Y
	//Scharr( src, grad_y, ddepth, 0, 1, scale, delta, BORDER_DEFAULT );
	Sobel( src, grad_y, ddepth, 0, 1, kernel_size, scale, delta, BORDER_DEFAULT );
	convertScaleAbs( grad_y, abs_grad_y );
	
	/// Total Gradient (approximate)
	addWeighted( abs_grad_x, 0.5, abs_grad_y, 0.5, 0, image );
	
	delete data_copy;
}



// http://docs.opencv.org/doc/tutorials/imgproc/imgtrans/canny_detector/canny_detector.html#canny-detector
+ (void)filterCanny:(Mat)image withKernelSize:(int)kernel_size andLowThreshold:(int)lowThreshold;
{
	int ratio = 3;
	
	
	const int& width = (int)image.cols;
	const int& height = (int)image.rows;
	const int& bytesPerRow = (int)image.step[0];
	
	// we need to copy because src.data != dst.data must hold with bilateral filter
	unsigned char* data_copy = new unsigned char[max(width,bytesPerRow)*height];
	memcpy(data_copy, image.data, max(width,bytesPerRow)*height);
	
	Mat src(height, width, CV_8UC1, data_copy, bytesPerRow);
	
	Mat detected_edges;
	
	/// Reduce noise with a kernel 3x3
	blur( src, detected_edges, cv::Size(3,3) );
	
	/// Canny detector
	Canny( detected_edges, detected_edges, lowThreshold, lowThreshold*ratio, kernel_size );
	
	/// Using Canny's output as a mask, we display our result
	image = Scalar::all(0);
	
	src.copyTo( image, detected_edges);
}



+ (void)filterBlurHomogeneousAccelerated:(Mat)image withKernelSize:(int)kernel_size;
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



+ (void)filterBlurGaussianAccelerated:(Mat)image withKernelSize:(int)kernel_size;
{
	// Allocate memory for final result
	const int& width = image.cols;
	const int& height = image.rows;
	const size_t& bytesPerRow = image.step[0];
	
	Pixel_8 *inData = (Pixel_8 *)malloc( bytesPerRow * height );
	memcpy(inData, image.data, bytesPerRow * height);
	
	// Create kernel
	float sigma = 0.3*(kernel_size/2-1) + 0.8;
	Mat kernel1D = getGaussianKernel(kernel_size, sigma);
	cout << "gaussian kernel 1D for size " << kernel_size << " end sigma " << sigma << endl;
	cout << kernel1D << endl;
	cout << endl;
	
	Mat kernel2D = kernel1D * kernel1D.t();
	cout << "gaussian kernel 2D for size " << kernel_size << " end sigma " << sigma << endl;
	cout << kernel2D << endl;
	cout << endl;
	
	
	vImage_Buffer image_in = { inData, static_cast<vImagePixelCount>(height), static_cast<vImagePixelCount>(width), bytesPerRow };
	vImage_Buffer image_out = { image.data, static_cast<vImagePixelCount>(height), static_cast<vImagePixelCount>(width), bytesPerRow };
	
	// Convolve using Accelerate framework
	vImageConvolve_Planar8(&image_in,
						   &image_out,
						   NULL,
						   0,
						   0,
						   kernel2D.ptr<int16_t>(),
						   kernel_size,
						   kernel_size,
						   1,
						   0,
						   kvImageBackgroundColorFill);
	
	free(inData);
}


// TODO
+ (void)filterBlurMedianAccelerated:(Mat)image withKernelSize:(int)kernel_size;
{
	cv::Mat dst = image;
	cv::medianBlur ( image, dst, kernel_size );
}


// TODO
+ (void)filterBlurBilateralAccelerated:(Mat)image withKernelSize:(int)kernel_size;
{
	const int& width = (int)image.cols;
	const int& height = (int)image.rows;
	const int& bytesPerRow = (int)image.step[0];
	
	// we need to copy because src.data != dst.data must hold with bilateral filter
	unsigned char* data_copy = new unsigned char[max(width,bytesPerRow)*height];
	memcpy(data_copy, image.data, max(width,bytesPerRow)*height);
	
	cv::Mat src(height, width, CV_8UC1, data_copy, bytesPerRow);
	
	bilateralFilter ( src, image, kernel_size, kernel_size*2, kernel_size/2 );
	
	delete data_copy;
}
#endif


@end
