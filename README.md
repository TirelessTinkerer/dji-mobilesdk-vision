# dji-mobilesdk-vision
Do computer vision with a DJI drone and a mobile device.

This project opens the door of using DJI's consumer drones, to do near-real-time computer vision. It takes advantage of DJI's advanced long distance video transmission link and the Mobile SDK, and demonstrates how to access the frames of the live video feed, do any computer vision and machine learning tricks you like on the mobile device, and take actions based on your needs.

## What you need
1. A DJI drone that supports Mobile SDK: Phantom, Inspire, Mavic, and even the tiny Spark. (I tested it on Mavic and Spark).

2. At this moment, only iOS demo is provided. So you'll need a Mac to build the code, and an iPhone or iPad to run the App.

## How to build
1. Follow the DJI Mobile SDK's [documentation](https://developer.dji.com/mobile-sdk/documentation/application-development-workflow/workflow-integrate.html#xcode-project-integration) to do necessary setup. Basically, you will need to install xcode, [cocoapods](https://guides.cocoapods.org/using/getting-started.html#getting-started), and register an App key from DJI developer [website](http://developer.dji.com/register/). When registering the App key, you need to have a unique bundle identifier like `com.yourorganization.yourappname`.

2. Clone this repo to /Users/username/dji-mobilesdk-vision

3. Clone https://github.com/dji-sdk/Mobile-SDK-iOS to /Users/username/Mobile-SDK-iOS . 

4. Download opencv2.framework from the official opencv [website](http://opencv.org/releases.html) and select the latest iOS pack of OpenCV 3.x. Put the opencv2.framework to path dji-mobilesdk-vision/drone-cv. 

5. Open a terminal, cd into /Users/username/dji-mobilesdk-vision/drone-cv, and run `pod install`. This step may take some time.

6. Open /Users/username/dji-mobilesdk-vision/drone-cv/drone-cv.xcworkspace.

7. Put the App key you applied from DJI developer website (in step 1) in the `DJISDKAppKey` entry in Info.plist file. Put the bundle identifier associated with the App Key the General settings of the drone-cv.

8. Build the code, side load to your iOS device, connect your Phone to the RC of the drone.
