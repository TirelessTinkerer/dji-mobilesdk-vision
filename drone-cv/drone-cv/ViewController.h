//
//  ViewController.h
//  drone-cv
//
//  Created by Zhiyuan Li on 7/6/17.
//  Copyright © 2017 dji. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

enum ImgProcess_Mode {
    IMG_PROC_DEFAULT,
    IMG_PROC_BLUR_GAUSSIAN,
    IMG_PROC_LAPLACIAN,
    IMG_PROC_FACE_DETECT,
    IMG_PROC_USER_1,
    IMG_PROC_USER_2,
    IMG_PROC_USER_3,
    IMG_PROC_USER_4,
    IMG_PROC_AR
};
@end

