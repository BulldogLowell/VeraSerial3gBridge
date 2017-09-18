![ThreeGee1 Logo](http://konektedplay.com/threegee/assets/threegee-default.png)
# [Vera](http://getvera.com "getvera.com")-Serial to 3G Bridge featuring [Particle Electron](https://store.particle.io/?utm_source=ADWORDS&utm_medium=CPC&utm_campaign=Branded&ads_cmpid=678296808&ads_adid=34991192352&ads_matchtype=b&ads_network=g&ads_creative=191119814318&utm_term=particle%20electron&ads_targetid=kwd-261025688856&utm_source=adwords&utm_medium=ppc&ttv=2&gclid=CjwKCAjw3f3NBRBPEiwAiiHxGBDCyxr_WXZ1caIwNNZXcDzRbsz9a3IZqZVRQ_vidghuTnk1t04eQhoCBKwQAvD_BwE "particle.io")

### An easy-to-build Serial Bridge that will enable your Vera Device to transmit 3G messaging (SMS or notification services like [Pushover](https://pushover.net "pushover.net")) and the ability to get notifications Via 3G in the case of *power loss* or *loss of internet* connectivity.

#### Uses [Particle Electron](https://store.particle.io/?utm_source=ADWORDS&utm_medium=CPC&utm_campaign=Branded&ads_cmpid=678296808&ads_adid=34991192352&ads_matchtype=b&ads_network=g&ads_creative=191119814318&utm_term=particle%20electron&ads_targetid=kwd-261025688856&utm_source=adwords&utm_medium=ppc&ttv=2&gclid=CjwKCAjw3f3NBRBPEiwAiiHxGBDCyxr_WXZ1caIwNNZXcDzRbsz9a3IZqZVRQ_vidghuTnk1t04eQhoCBKwQAvD_BwE "particle.io") to communicate over 3G wireless services and an [Arduino Nano](https://store.arduino.cc/usa/arduino-nano "arduino.cc") to bridge the serial communication and buffer messages while the Electron sleeps.  This sleep method is used in order to keep the data costs to a minimum.  Using the [Particle.io](https://www.particle.io "particle.io") services, *the montly cost to operate is less than $3.00 per month*.

## Setup Instructions:
### 1. Create a Pushover Account
Follow the [instructions here](https://pushover.net/signup) to create a Pushover Account, set up your recieving devices and take careful note of your API key.
***
### 2. Create a Particle Account
Follow the [instructions here](https://login.particle.io/signup?redirect=https%3A//www.particle.io/) to create a Particle Account. Familiarize yourself with the Particle device.  Learn how to perform a Flash via the [Particle Web IDE](https://build.particle.io).  Don't forget to register your SIM.
***
### 3. Flash your Particle Electron
You can select [DFU flash](https://docs.particle.io/faq/particle-tools/installing-dfu-util/electron/) (no Cellular Data Used) from the command line or do it Over The Air (OTA flash will use cellular data).
***
### 4. Create a Particle Webhook
Login to the Particle Console and select [Integrations](https://console.particle.io/integrations).  Create and save Webhook identical to this:

![First Page](https://github.com/BulldogLowell/VeraSerial3gBridge/blob/master/images/WebHook1.png)
![Second Page](https://github.com/BulldogLowell/VeraSerial3gBridge/blob/master/images/WebHook2.png)
***
### 5. Test Your WebHook
Press the Test Button to make sure your Integration is working:

![Test Page](https://github.com/BulldogLowell/VeraSerial3gBridge/blob/master/images/WebHookTest.png)
***
### 6. Flash your Arduino Nano
Using the Arduino IDE, be sure to select Nano as the target device and flash the GitHub Code to your Nano
***
### 7. Wire Up Your Devices:
You can wire up the device like this (or optionaly power the Electron by its USB connection... better).

![FritzingDiagram](https://github.com/BulldogLowell/VeraSerial3gBridge/blob/master/images/FritzingDiagram.png)
***
### 8. Attach the Nano's USB cable to your Vera's on-board Serial USB connection.
Depending on your unit, the USB connection location may vary.
***
### 9. Install the Vera Plugin
Select **APPS** -> **Develop Apps** -> **Luup Files**
Drag and drop all 5 ThreeGee1 files into the destination directory for plugins and Wait for files to upload.

![Plugin Install](https://github.com/BulldogLowell/VeraSerial3gBridge/blob/master/images/LuupFiles.png)
***
### 10. Create a ThreeGee1 Device
Select **APPS** -> **Develop Apps** -> **Create Device** enter the device's XML file name **D_ThreeGee1.xml** and select **Create device**.

![Create Device](https://github.com/BulldogLowell/VeraSerial3gBridge/blob/master/images/CreateDevice.png)

Re-Boot your Vera Device; this process takes about 5 minutes.  You should then see your device with the following message:

![Vera Serial Error](https://github.com/BulldogLowell/VeraSerial3gBridge/blob/master/images/DeviceSerialError.png)
***
### 11. Configure the Serial Device
Select **APPS** -> **Develop Apps** -> **Serial Port Configuration**
You should see your FTDI (Serial) connected Nano on the list of Serial Devices.  If not, wait a few minutes and try again, as per the on-screen instructions.
Select the new ThreeGee Gateway device in the drop-down and set the Baud Rate to 115200, Data Bits to 8, Stop Bits to 1 and Parity to None as in this image:

![Serial Setup](https://github.com/BulldogLowell/VeraSerial3gBridge/blob/master/images/SerialSetup.png)
***
### 12. Re-Boot your Vera... your setup is complete!
***
## Operating Instructions:
### 1. Arm your device
If **Armed** Vera will push messages to your 3G gateway, if **Disarmed** messages will not be sent.
*The main panel displays messages as it Pings the gateway, Internet and sends a 3G message.*
![MainPanel](https://github.com/BulldogLowell/VeraSerial3gBridge/blob/master/images/VeraMainPanel.png)
***
### 2. Configure your settings
The Control Panel appears with the default (preferred) settings showing as:

![ControlPanel](https://github.com/BulldogLowell/VeraSerial3gBridge/blob/master/images/VeraControlPanel.png)

You can set the 
  * **GateWay Timeout:** The time (minutes) that the gateway will send an alert if Vera stops communicating.
  * **Ping Frequency:** The time (seconds) that the Vera will send a ping to the gateway and to the internet.  Vera looks for a response from both the gateway and the internet.
  * **Ping Timeout:** The time (seconds) that Vera, in the absense of a return ping from the Gateway will display as "Tripped".  It is also the timeout for returning a successful ping from the internet
  * **IP or Domain:** The IP address or domain of the external server to return a Ping.  Default is *google.com*.
  * **IP Notify Retries:** The number of times that the gateway will re-send an alert if Vera stops communicating to the internet.

Send a message by inputting text (32 char max) into the appropriate text box and press **Send**.

![ThreeGee Rocks](https://github.com/BulldogLowell/VeraSerial3gBridge/blob/master/images/ThreeGeeRocks.png)
***
## Some Operating Notes:
  * Messages take several seconds to send as the Electron is awoken from sleep and re-connects to the Mobile Network.
  * Messages will buffer (up to 10) so 3G messages should be limited to the most important if the internet is disconnected.  
  * You can determine the state of the IP Ping checking the **InternetPing** variable **ServiceID:** *urn:konektedplay-com:serviceId:ThreeGee1*, "0" is success "1" is failed.
  * Device will report **Tripped** variable **ServiceID:** *urn:micasaverde-com:serviceId:SecuritySensor1* "1" = Tripped, "0" = Not Tripped.  You can have Vera send a message that the Gateway is down (in this case, gateway stopped functioning but Internet is still connected).
  ***
## Coming Soon:
  * Automatic Power Cycling of Vera (relay control) if inactive for a defined period.
