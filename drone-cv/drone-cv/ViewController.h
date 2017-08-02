//
//  ViewController.h
//  drone-cv
//
//  Created by Arjun Menon on 7/6/17.
//  Copyright © 2017 dji. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

enum ImgProcess_Mode {
    IMG_PROC_DEFAULT,
    IMG_PROC_BLUR_HOMOGENEOUS,
    IMG_PROC_BLUR_GAUSSIAN,
    IMG_PROC_BLUR_MEDIAN,
    IMG_PROC_BLUR_BILATERAL,
    IMG_PROC_LAPLACIAN,
    IMG_PROC_SOBEL,
    IMG_PROC_CANNY,
    IMG_PROC_HARRIS,
    IMG_PROC_FACE_DETECT
};
@end

