//
//  ViewController.h
//  drone-cv
//
//  Created by Arjun Menon on 7/6/17.
//  Copyright © 2017 dji. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

enum Filter_Mode {
    FILTERMODE_DEFAULT,
    FILTERMODE_BLUR_HOMOGENEOUS,
    FILTERMODE_BLUR_GAUSSIAN,
    FILTERMODE_BLUR_MEDIAN,
    FILTERMODE_BLUR_BILATERAL,
    FILTERMODE_LAPLACIAN,
    FILTERMODE_SOBEL,
    FILTERMODE_CANNY,
    FILTERMODE_HARRIS
};
@end

