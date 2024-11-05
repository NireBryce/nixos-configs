# find event name with `sudo libinput list-devices`
middle-mouse-scroll EVENT_NAME:
  qdbus org.kde.KWin /org/kde/KWin/InputDevice/{{EVENT_NAME}} org.kde.KWin.InputDevice.scrollOnButtonDown true
