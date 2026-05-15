# Guardian Eye Faculty Demo Guide

## Goal
Show a working mobile-controlled home security surveillance system using:
- Flutter Android app
- Raspberry Pi backend
- Real detection, alerts, live feed, and face management

## Before Demo

### 1. Raspberry Pi
Open terminal on the Raspberry Pi and run:

```bash
cd ~/guardian_eye/pi_code
python3 api_server.py
```

Check health:

```bash
curl http://localhost:5000/api/health
```

Expected:
- API server should be running
- Raspberry Pi IP should be known

### 2. Mobile App
Run the Flutter app:

```bash
flutter run
```

### 3. Verify Before Entering Room
- Login works
- Pi is connected
- Home screen shows `Pi Online`
- Live Camera opens
- Detection can start
- Alerts tab loads
- Face Database opens

## Recommended Demo Flow

### Step 1. Project Introduction
Say:

`Guardian Eye is a mobile-controlled smart home security system. The Raspberry Pi performs detection and recognition, and the Android app acts as the control and monitoring dashboard.`

### Step 2. Show Pi Connection on Home
Open:
- Home

Show:
- Pi online/offline state
- Armed/disarmed/night mode state
- Detection state
- Unread alert count

Say:

`The app always reflects the real Raspberry Pi runtime state, including whether detection is active.`

### Step 3. Start Detection
From:
- Home `Detect`
or
- `Pi Camera Controls`

Show:
- Detection starts
- Home banner updates

Say:

`The detection engine can be started and stopped directly from the mobile app.`

### Step 4. Open Live Camera
Open:
- Camera
- Pi Camera

Show:
- Live feed
- FPS badge
- Snapshot button
- State line in app bar

Say:

`This is the real live feed coming from the Raspberry Pi pipeline.`

### Step 5. Arm the System
From:
- Home `Arm`

Show:
- Arm confirmation
- Banner changes to armed

Then optionally enable:
- Night mode

Say:

`The user can control the system mode from the phone without touching the Raspberry Pi.`

### Step 6. Trigger a Real Event
Do one of these:
- Walk into frame
- Trigger motion
- Show an unknown person

Show:
- In-app foreground alert banner
- Bottom nav unread badge
- Alert appears in Alerts screen

Say:

`When an event happens, the app receives the alert immediately while open, and it is also stored in the alert history.`

### Step 7. Open Alerts
Open:
- Alerts

Show:
- Latest unread alert banner
- Alert categories
- Mark read
- Dismiss
- Clear all

Say:

`The app supports live alert handling, filtering, and alert management.`

### Step 8. Snapshot and History
From:
- Live Camera -> capture snapshot
- History / Snapshots

Show:
- Snapshot appears in history
- Open snapshot
- Delete snapshot if needed

Say:

`The system also keeps visual evidence that can be reviewed from the app.`

### Step 9. Face Database
Open:
- Settings
- Face Database

Show:
- Registered people list
- Search
- Retrain
- Delete

Say:

`Known face management is also done through the app.`

### Step 10. Add a New Person Using Phone Camera
Open:
- Face Database
- Add Person

Show:
- Enter name
- Use phone camera
- Capture multiple face photos
- Upload to Pi
- Person appears in database

Say:

`This flow does not require using the Raspberry Pi camera for registration. The mobile app captures the face data and sends it to the Pi for training.`

## Strongest Feature Set To Highlight
- Real Pi connection status
- Live camera feed
- Detection start/stop from mobile
- Arm/disarm from mobile
- Night mode from mobile
- Real alerts with in-app banners
- Snapshot history
- Mobile-camera face registration
- Face database management

## Best Demo Order
1. Home status
2. Start detection
3. Live feed
4. Arm system
5. Trigger alert
6. Show Alerts tab
7. Show snapshot/history
8. Show face database
9. Add person from app

## If Something Fails

### Pi offline
Check:

```bash
python3 api_server.py
hostname -I
```

### Live feed unavailable
Check:
- Pi is online
- detection is running

### Alerts not appearing
Check:
- detection running
- event actually triggered
- Alerts tab refresh

### Face registration fails
Check:
- Pi server is still running
- app still connected to Pi
- phone camera permission granted

## Avoid During Demo
- Do not keep switching Wi-Fi
- Do not stop the Pi server mid-demo
- Do not open unrelated unfinished screens
- Do not rely on edge-case rapid tapping

## Backup Plan
If time is short, demo this minimum set:
1. Home state
2. Start detection
3. Live feed
4. Arm/disarm
5. Trigger alert
6. Alerts tab
7. Face database

## Demo Closing Line
`This system demonstrates a practical home security workflow where monitoring, control, alerts, and face registration are all managed from the mobile application while the Raspberry Pi handles the local intelligence.`
