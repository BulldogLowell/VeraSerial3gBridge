#include <SoftwareSerial.h>
#include <EEPROM.h>

enum ElectronState{
  ELECTRON_SLEEP,
  ELECTRON_WAIT_FOR_READY,
  ELECTRON_READY,
  ELECTRON_HOLDING_FOR_SLEEP
};

struct DeviceSettings {
  uint32_t commTimeout = 2 * 60 * 1000L;
  bool timeoutActive = true;
} deviceSettings;

ElectronState electronState = ELECTRON_HOLDING_FOR_SLEEP;
ElectronState lastState = ELECTRON_SLEEP;

const uint32_t ELECTRON_SLEEP_TIMEOUT = 10000;
const size_t MESSAGE_BUFFER_SIZE = 10;
const size_t MAX_MESSAGE_LENGTH = 64;
const size_t ACK_MSSG_LENGTH = 8;

SoftwareSerial ElectronSerial(A4, A5);

const int onboardLedPin = 13;
const int relayPin = A2;
const int wakeupPin = A1;
const int powerupSensorPin = A0;

int sendRetyrAttempts = 0;

char pendingMessages[MESSAGE_BUFFER_SIZE][MAX_MESSAGE_LENGTH];

HardwareSerial& VeraSerial = Serial;
//HardwareSerial& DEBUG = Serial;

void setup()
{
  VeraSerial.begin(115200);
  ElectronSerial.begin(57600);
  pinMode(wakeupPin, OUTPUT);
  digitalWrite(wakeupPin, HIGH);
  pinMode(onboardLedPin, OUTPUT);
  digitalWrite(onboardLedPin, LOW);
  pinMode(powerupSensorPin, OUTPUT);
  digitalWrite(powerupSensorPin, LOW);
  delay(1000);
  digitalWrite(powerupSensorPin, HIGH);
  digitalWrite(wakeupPin, LOW);
  //EEPROM.put(0, deviceSettings);
  EEPROM.get(0, deviceSettings);
  //DEBUG.print(F("DEBUG:\t"));
  //DEBUG.print(F("Re-Start\n"));
}

void loop()
{
  static uint32_t lastElectronStateChangeMilllis = millis();
  static uint32_t pingMillis = 0;

  if (lastState != electronState)
  {
    switch (electronState)
    {
      case ELECTRON_SLEEP:
        //DEBUG.print(F("DEBUG:\t"));
        //DEBUG.print(F("Entered ELECTRON_SLEEP state\n"));
        break;
      case ELECTRON_WAIT_FOR_READY:
        //DEBUG.print(F("DEBUG:\t"));
        //DEBUG.print(F("Entered ELECTRON_WAIT_FOR_READY state\n"));
        break;
      case ELECTRON_READY:
        //DEBUG.print(F("DEBUG:\t"));
        //DEBUG.print(F("Entered ELECTRON_READY state\n"));
        break;
      case ELECTRON_HOLDING_FOR_SLEEP:
        //DEBUG.print(F("DEBUG:\t"));
        //DEBUG.print(F("Entered ELECTRON_HOLDING_FOR_SLEEP state\n"));
        break;
      default:
        break;
    }
    lastState = electronState;
  }

  switch (electronState)
  {
    case ELECTRON_SLEEP:
      if (strlen(pendingMessages[0]))
      {
        //DEBUG.print(F("DEBUG:\t"));
        //DEBUG.print(F("Got Message\n"));
        digitalWrite(onboardLedPin, HIGH);
        wakeElectron();
        lastElectronStateChangeMilllis = millis();
        electronState = ELECTRON_WAIT_FOR_READY;
      }
      break;
    case ELECTRON_WAIT_FOR_READY:
      if (const char* electronMessg = checkForElectronMessage(ElectronSerial, '\n'))
      {
        if (strstr(electronMessg, "OK"))
        {
          //DEBUG.print(F("DEBUG:\t"));
          //DEBUG.print(F("Got OK from Electron\n"));
          lastElectronStateChangeMilllis = millis();
          electronState = ELECTRON_READY;
        }
      }
      if (millis() - lastElectronStateChangeMilllis > 2 * ELECTRON_SLEEP_TIMEOUT)
      {
        //DEBUG.print(F("DEBUG:\t"));
        //DEBUG.print(F("Electron Not Ready, timeout\n"));
        lastElectronStateChangeMilllis = millis();
        electronState = ELECTRON_HOLDING_FOR_SLEEP;
      }
      break;
    case ELECTRON_READY:
      if (sendPendingElectronMessages())
      {
        //DEBUG.print(F("DEBUG:\t"));
        //DEBUG.print(F("Message Sent\n"));
        lastElectronStateChangeMilllis = millis();
      }
      else if (const char* electronMessg = checkForElectronMessage(ElectronSerial, '\n'))
      {
        if (strstr(electronMessg, "SLEEP"))
        {
          //DEBUG.print(F("DEBUG:\t"));
          //DEBUG.print(F("Electron ready for sleep\n"));
          lastElectronStateChangeMilllis = millis();
          electronState = ELECTRON_HOLDING_FOR_SLEEP;
        }
      }
      else if (millis() - lastElectronStateChangeMilllis > ELECTRON_SLEEP_TIMEOUT)
      {
        //ElectronSerial.println(F("SLEEP"));
        //DEBUG.print(F("DEBUG:\t"));
        //DEBUG.print(F("No Message timeout\n"));
        lastElectronStateChangeMilllis = millis();
        electronState = ELECTRON_HOLDING_FOR_SLEEP;
      }
      break;
    case ELECTRON_HOLDING_FOR_SLEEP:
      if (millis() - lastElectronStateChangeMilllis > (2 * ELECTRON_SLEEP_TIMEOUT))
      {
        //DEBUG.print(F("DEBUG:\t"));
        //DEBUG.print(F("Hold Complete, entering ELECTRON_SLEEP state\n"));
        digitalWrite(onboardLedPin, LOW);
        electronState = ELECTRON_SLEEP;
      }
      break;
    default:
        break;
  }


  if (char* veraMessage = checkForVeraMessage(VeraSerial, '\n'))
  {
    VeraSerial.println(veraMessage);  // always immediately echo the message
    if (strstr(veraMessage, "MSSG"))  // message to Electron
    {
      char alert[MAX_MESSAGE_LENGTH];
      strcpy(alert, veraMessage);
      strtok(alert, ":");
      strcpy(alert, strtok(NULL, ":")); // just send the message part, not the header
      if (int activeMssgs = addMssgToSendBuffer(alert) > MESSAGE_BUFFER_SIZE - 1)
      {
        VeraSerial.print(F("Message Buffer Full: "));
        VeraSerial.print(activeMssgs);
        VeraSerial.print(F(" messages\n"));
      }
      else
      {
        VeraSerial.print(F("Sent: "));
        VeraSerial.println(alert);
      }
    }
    else if (strstr(veraMessage, "PING"))
    {
      char ping[MAX_MESSAGE_LENGTH];
      strcpy(ping, veraMessage);
      strtok(ping, ":");
      int newTimeout = atol(strtok(NULL, ":"));
      if (newTimeout > 0)
      {
        deviceSettings.timeoutActive = true;
        newTimeout = constrain(newTimeout, 1, 60);
        deviceSettings.commTimeout = newTimeout * 60 * 1000UL;
        EEPROM.put(0, deviceSettings);
      }
      else if (newTimeout == 0)
      {
        deviceSettings.timeoutActive = false;
        EEPROM.put(0, deviceSettings);
      }
      VeraSerial.println(veraMessage);
      pingMillis = millis();
    }
    else if (strstr(veraMessage, "GWTO"))  //GateWay TimeOut
    {
      char gatewayTimeout[MAX_MESSAGE_LENGTH];
      strcpy(gatewayTimeout, veraMessage);
      strtok(gatewayTimeout, ":");
      int newTimeout = atol(strtok(NULL, ":"));
      if (newTimeout > 0)
      {
        deviceSettings.timeoutActive = true;
        newTimeout = constrain(newTimeout, 1, 60);
        deviceSettings.commTimeout = newTimeout * 60 * 1000UL;
        EEPROM.put(0, deviceSettings);
      }
      else if (newTimeout == 0)
      {
        deviceSettings.timeoutActive = false;
        EEPROM.put(0, deviceSettings);
      }
      VeraSerial.print(F("Gateway Timeout: "));
      VeraSerial.print(newTimeout);
      VeraSerial.print(F(" minutes.\n"));
    }
    //digitalWrite(onboardLedPin, LOW);
  }
}

int addMssgToSendBuffer(const char* mssg)
{
  for (int i = 0; i < MESSAGE_BUFFER_SIZE; i++)
  {
    if (!strlen(pendingMessages[i]))
    {
      strcpy(pendingMessages[i], mssg);
    }
    return i;
  }
}

char* checkForVeraMessage(Stream& stream, const char endMarker)
{
  static char incomingMessage[MAX_MESSAGE_LENGTH] = "";
  static byte idx = 0;
  if (stream.available())
  {
    if(stream.peek() == '\r')  // filter out the CR from Vera
    {
      (void)stream.read();
      return nullptr;
    }
    incomingMessage[idx] = stream.read();
    if (incomingMessage[idx] == endMarker)
    {
      incomingMessage[idx] = '\0';
      idx = 0;
      return incomingMessage;
    }
    else
    {
      idx++;
      if (idx > MAX_MESSAGE_LENGTH - 1)
      {
        stream.print(F("{\"error\":\"message too long\"}\n"));  //you can send an error to sender here
        idx = 0;
        incomingMessage[idx] = '\0';
      }
    }
  }
  return nullptr;
}

void wakeElectron(void)
{
  digitalWrite(wakeupPin, HIGH);
  delay(100);
  digitalWrite(wakeupPin, LOW);
}

bool sendPendingElectronMessages()
{
  static uint32_t lastTransmitMillis = 0;
  if (strlen(pendingMessages[0]))
  {
    if(millis() - lastTransmitMillis > 1000)
    {
      ElectronSerial.println(pendingMessages[0]);
      ElectronSerial.flush();
      for (int i = 0; i < MESSAGE_BUFFER_SIZE; i++)
      {
        if (i < MESSAGE_BUFFER_SIZE - 1)
        {
          strcpy(pendingMessages[i], pendingMessages[i+1]);
        }
        else
        {
          strcpy(pendingMessages[i], "");
        }
      }
      lastTransmitMillis = millis();
    }
  }
  return strlen(pendingMessages[0]) > 0;
}

const char* checkForElectronMessage(Stream& stream, const char endMarker)
{
  static char incomingMessage[MAX_MESSAGE_LENGTH] = "";
  static byte idx = 0;
  if (stream.available())
  {
    incomingMessage[idx] = stream.read();
    if (incomingMessage[idx] == endMarker)
    {
      incomingMessage[idx] = '\0';
      idx = 0;
      return incomingMessage;
    }
    else
    {
      idx++;
      if (idx > MAX_MESSAGE_LENGTH - 1)
      {
        stream.print(F("{\"error\":\"message too long\"}\n"));  //you can send an error to sender here
        idx = 0;
        incomingMessage[idx] = '\0';
      }
    }
  }
  return nullptr;
}
