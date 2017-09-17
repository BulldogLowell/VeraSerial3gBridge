const size_t MAX_MESSAGE_LENGTH = 64;
const size_t MESSSAGE_BUFFER_SIZE = 20;

enum ELECTRON_STATE{
  ELECTRON_WAKE,
  ELECTRON_READY,
  ELECTRON_SLEEP_TIMER,
  ELECTRON_SLEEP_DEEP,
};

struct DeviceSettings{
  int repeatMins = 30;
  int sleepTimeout = 3000;
};

FuelGauge fuel;

const int wakeupPin = A2;
const int sensorPin = A1;

USBSerial& DebugSerial = Serial;
USARTSerial& NanoSerial = Serial1;

retained bool mssgSent = false;
retained uint32_t lastEventMillis;
retained DeviceSettings deviceSettings;
retained ELECTRON_STATE state = ELECTRON_WAKE;
retained char pendingMessages[MESSSAGE_BUFFER_SIZE][MAX_MESSAGE_LENGTH];
retained char incomingMessage[MAX_MESSAGE_LENGTH] = "";
retained byte idx = 0;

void setup()
{
  NanoSerial.begin(57600);
  DebugSerial.begin(115200);

  // uncomment this followig block of code the first time you flash your Electron
  // then comment it back out and reflash your device

  /*deviceSettings.repeatMins = 2;
  deviceSettings.sleepTimeout = 3000;
  EEPROM.put(0, deviceSettings);*/

  EEPROM.get(0, deviceSettings);
  pinMode(D7, OUTPUT);
  pinMode(sensorPin, INPUT);
  pinMode(wakeupPin, INPUT);
  uint32_t startupMillis = millis();
}

void loop()
{
  if (!Particle.connected())
  {
    Particle.connect();
  }
  bool powerState = digitalRead(sensorPin);
  float chargeState = fuel.getSoC();

  switch(state)
  {
    case ELECTRON_WAKE:
      digitalWrite(D7, HIGH);  // indicate active
      NanoSerial.println("OK");
      NanoSerial.flush();
      DebugSerial.print("Woke\n");
      lastEventMillis = millis();
      state = ELECTRON_READY;
      break;

    case ELECTRON_READY:
      if (powerState)
      {
        if (const char* newMessage = checkForNewMessage(NanoSerial, '\n'))
        {
          DebugSerial.print("GOT NEW MESSAGE FROM NANO\n");
          if (strcmp(newMessage, "OK") == 0)
          {
            NanoSerial.println(newMessage);
            NanoSerial.flush();
          }
          else if (strstr(newMessage, "SREP~"))  // set repeat minutes for a power loss
          {
            char mssg[MAX_MESSAGE_LENGTH] = "";
            strcpy(mssg, newMessage);
            strtok(mssg, "~");
            int newRepeatInterval = atoi(strtok(NULL, "~"));
            deviceSettings.repeatMins = constrain(newRepeatInterval, 5, 120);
            EEPROM.put(0, deviceSettings);
            NanoSerial.println(newMessage);
            NanoSerial.flush();
          }
          else if (strstr(newMessage, "PROGRAM~"))
          {
            Particle.publish("pushover", "Electron in Programming Mode", 60, PRIVATE);
            while(millis() - lastEventMillis < 60 * 1000)  // allow time for OTA flash...
            {
              Particle.process();
            }
            Particle.publish("pushover", "Electron Programming Mode Ended", 60, PRIVATE);
          }
          else
          {
            DebugSerial.print("3G outgoing message recieved:\t");
            DebugSerial.println(newMessage);
            if (int activeMssgs = addMssgToSendBuffer(newMessage) > MESSSAGE_BUFFER_SIZE)
            {
              DebugSerial.print("Message Buffer Full: ");
              DebugSerial.print(activeMssgs);
              DebugSerial.print(" messages\n");
            }
            else
            {
              DebugSerial.print("COMPLETED: ADDED MESSAGE TO BUFFER\n");
            }
          }
          lastEventMillis = millis();
        }
      }

      if (strlen(pendingMessages[0]))
      {
        publishPendingMessages();
        mssgSent = true;
        lastEventMillis = millis();
      }
      if (millis() - lastEventMillis > deviceSettings.sleepTimeout)
      {
        if(!mssgSent)
        {
          DebugSerial.print("no messages sent...\n");
          const int messageLength = 64;
          char pushoverMessage[messageLength];
          snprintf(pushoverMessage, sizeof(pushoverMessage), "Gateway: %s  Battery: %.1f%%", powerState? "Restart." : "Power Loss.", chargeState);
          Particle.publish("pushover", pushoverMessage, 60, PRIVATE);
          lastEventMillis = millis();
        }
        mssgSent = false;
        state = powerState? ELECTRON_SLEEP_DEEP : ELECTRON_SLEEP_TIMER;
      }
      break;

    case ELECTRON_SLEEP_TIMER:
      DebugSerial.print("commencing timer sleep...\n");
      state = ELECTRON_WAKE;
      digitalWrite(D7, LOW);
      System.sleep(wakeupPin, CHANGE, 60 * deviceSettings.repeatMins);
      break;

    case ELECTRON_SLEEP_DEEP:
      DebugSerial.print("commencing deep sleep...\n");
      state = ELECTRON_WAKE;
      digitalWrite(D7, LOW);
      System.sleep(wakeupPin, CHANGE);
      break;
  }
}

bool publishPendingMessages()
{
  static uint32_t lastPublishMillis = 0;
  if (strlen(pendingMessages[0]) > 0)
  {
    if (millis() - lastPublishMillis > 1000) // meets rate limiting requirements
    {
      char taggedMessage[128];
      snprintf(taggedMessage, sizeof(taggedMessage), "%s: %s", Time.timeStr().c_str(), pendingMessages[0]);
      Particle.publish("pushover", taggedMessage, 60, PRIVATE);
      DebugSerial.print("PUBLISHED PENDING MESSAGE:\t");
      DebugSerial.println(taggedMessage);
      mssgSent = true;
      for (int i = 0; i < MESSSAGE_BUFFER_SIZE; i++)
      {
        if (i < MESSSAGE_BUFFER_SIZE - 1)
        {
          strcpy(pendingMessages[i], pendingMessages[i+1]);
        }
        else
        {
          strcpy(pendingMessages[i], "");
        }
      }

      lastPublishMillis = millis();
    }
  }
  return (strlen(pendingMessages[0]) > 0);
}

int addMssgToSendBuffer(const char* mssg)
{
  for (int i = 0; i < MESSSAGE_BUFFER_SIZE; i++)
  {
    if (strlen(pendingMessages[i]) == 0)
    {
      strcpy(pendingMessages[i], mssg);
      return i + 1;
    }
  }
  return -1;
}

char* checkForNewMessage(Stream& stream, const char endMarker)
{
  static char incomingMessage[MAX_MESSAGE_LENGTH] = "";
  static byte idx = 0;
  if (stream.available())
  {
    if (stream.peek() == '\r')
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
        stream.print(F("ERROR:\n"));  //you can send an error to sender here
        while (stream.available())
          (void)stream.read();
        idx = 0;
        incomingMessage[idx] = '\0';
      }
    }
  }
  return nullptr;
}
