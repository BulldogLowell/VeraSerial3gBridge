![ThreeGee1 Logo](http://konektedplay.com/threegee/assets/threegee-default.png)
# [Vera](http://getvera.com "getvera.com")-Serial to 3G Bridge featuring [Particle Electron](https://store.particle.io/?utm_source=ADWORDS&utm_medium=CPC&utm_campaign=Branded&ads_cmpid=678296808&ads_adid=34991192352&ads_matchtype=b&ads_network=g&ads_creative=191119814318&utm_term=particle%20electron&ads_targetid=kwd-261025688856&utm_source=adwords&utm_medium=ppc&ttv=2&gclid=CjwKCAjw3f3NBRBPEiwAiiHxGBDCyxr_WXZ1caIwNNZXcDzRbsz9a3IZqZVRQ_vidghuTnk1t04eQhoCBKwQAvD_BwE "particle.io")
***
### An easy-to-build Serial Bridge that will enable your Vera Device to transmit 3G messaging (SMS or notification services like [Pushover](https://pushover.net "pushover.net")) and the ability to get notifications Via 3G in the case of *power loss* or *loss of internet* connectivity.
***
#### Uses [Particle Electron](https://store.particle.io/?utm_source=ADWORDS&utm_medium=CPC&utm_campaign=Branded&ads_cmpid=678296808&ads_adid=34991192352&ads_matchtype=b&ads_network=g&ads_creative=191119814318&utm_term=particle%20electron&ads_targetid=kwd-261025688856&utm_source=adwords&utm_medium=ppc&ttv=2&gclid=CjwKCAjw3f3NBRBPEiwAiiHxGBDCyxr_WXZ1caIwNNZXcDzRbsz9a3IZqZVRQ_vidghuTnk1t04eQhoCBKwQAvD_BwE "particle.io") to communicate over 3G wireless services and an [Arduino Nano](https://store.arduino.cc/usa/arduino-nano "arduino.cc") to bridge the serial communication and buffer messages while the Electron sleeps.  This sleep method is used in order to keep the data costs to a minimum.  Using the [Particle.io](https://www.particle.io "particle.io") services, the montly cost to operate is less than $3.00 per month.

## Instructions
### 1. Create a Pushover Account
Follow the [instructions here](https://pushover.net/signup) to create a Pushover Account, set up your recieving devices and take careful note of your API key.
### 2. Create a Particle Account
Follow the [instructions here](https://login.particle.io/signup?redirect=https%3A//www.particle.io/) to create a Particle Account. Familiarize yourself with the Particle device.  Learn how to perform a Flash via the [Particle Web IDE](https://build.particle.io).
### 3. Flash your Particle Electron
You can select [DFU flash](https://docs.particle.io/faq/particle-tools/installing-dfu-util/electron/) (no Cellular Data Used) from the command line or do it Over The Air (OTA flash will use cellular data).
### 4. Create a Particle Webhook
Login to the Particle Console and select [Integrations](https://console.particle.io/integrations).  Create and save Webhook identical to this:

![First Page](https://github.com/BulldogLowell/VeraSerial3gBridge/blob/master/images/WebHook1.png)
![Second Page](https://github.com/BulldogLowell/VeraSerial3gBridge/blob/master/images/WebHook2.png)

### 5. Test Your WebHook
Press the Test Button to make sure your Integration is working:

![Test Page](https://github.com/BulldogLowell/VeraSerial3gBridge/blob/master/images/WebHookTest.png)

### 6. Flash your Arduino Nano
Using the Arduino IDE, be sure to select Nano as the target device and flash the GitHub Code to your Nano

### 7. Wire Up Your Devices:
You can wire up the device like this (or optionaly power the Electron by its USB connection... better).

![FritzingDiagram](https://github.com/BulldogLowell/VeraSerial3gBridge/blob/master/images/FritzingDiagram.png)

### 8. Attach the Nano's USB cable to your Vera's on-board Serial USB connection.
Depending on your unit, the USB connection location may vary.

### 9. Install the Vera Plugin
Select **APPS** -> **Develop Apps** -> **Luup Files**
Drag and drop all 5 ThreeGee1 files into the destination directory for plugins

![Plugin Install](https://github.com/BulldogLowell/VeraSerial3gBridge/blob/master/images/LuupFiles.png)

Wait for files to upload and re-Boot your Vera Device.
