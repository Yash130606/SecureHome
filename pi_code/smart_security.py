import gc
import json
import os
import pickle
import subprocess
import threading
import time
from datetime import datetime

import cv2
import numpy as np
import requests
from ultralytics import YOLO

print("=" * 45)
print("   Smart Security System v3.0")
print("   YOLO + Face + Zone + Loitering")
print("=" * 45)

print("\nLoading models...")
yolo_model = YOLO("models/yolov8n.pt")
print("YOLO loaded!")

recognizer = cv2.face.LBPHFaceRecognizer_create()
recognizer.read("models/face_model.yml")
with open("models/label_map.pkl", "rb") as f:
    label_map = pickle.load(f)
print("Face model loaded!")
print(f"Known: {list(label_map.values())}")

with open("models/zone_config.json", "r") as f:
    zone = json.load(f)
print(f"Zone loaded: {zone}")

face_cascade = cv2.CascadeClassifier(
    cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
)

local_state = {
    "armed": False,
    "night_mode": False,
    "confidence": 0.55,
    "loiter_sec": 9,
}

WIDTH, HEIGHT = 320, 240
CROWD_ALERT_COUNT = 3
NIGHT_START = 22
NIGHT_END = 6
SKIP_FRAMES = 8

IGNORE_LABELS = [
    "cat",
    "dog",
    "bird",
    "horse",
    "sheep",
    "cow",
    "elephant",
    "bear",
    "zebra",
    "giraffe",
]

os.makedirs("faces/unknown", exist_ok=True)
os.makedirs("captures", exist_ok=True)
os.makedirs("logs", exist_ok=True)

person_tracker = {}
unknown_count = 0


def sync_state_from_api():
    while True:
        try:
            res = requests.get("http://localhost:5000/api/status", timeout=2)
            if res.status_code == 200:
                data = res.json()
                local_state["armed"] = data.get("armed", False)
                local_state["night_mode"] = data.get("night_mode", False)
                local_state["confidence"] = data.get("confidence", 0.55)
                local_state["loiter_sec"] = data.get("loiter_sec", 9)
        except Exception:
            pass
        time.sleep(3)


sync_thread = threading.Thread(target=sync_state_from_api, daemon=True)
sync_thread.start()
print("State sync thread started!")


def log_event(event):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{timestamp}] {event}"
    print(line)
    with open("logs/security_log.txt", "a") as f:
        f.write(line + "\n")


def is_night_mode():
    if local_state["night_mode"]:
        return True
    hour = datetime.now().hour
    return hour >= NIGHT_START or hour < NIGHT_END


def in_alert_zone(x1, y1, x2, y2):
    zx1, zy1 = zone["x1"], zone["y1"]
    zx2, zy2 = zone["x2"], zone["y2"]
    return not (x2 < zx1 or x1 > zx2 or y2 < zy1 or y1 > zy2)


def draw_zone(display, alert_active=False):
    zx1 = zone["display_x1"]
    zy1 = zone["display_y1"]
    zx2 = zone["display_x2"]
    zy2 = zone["display_y2"]
    color = (0, 0, 255) if alert_active else (0, 165, 255)
    overlay = display.copy()
    cv2.rectangle(overlay, (zx1, zy1), (zx2, zy2), color, -1)
    cv2.addWeighted(overlay, 0.15, display, 0.85, 0, display)
    cv2.rectangle(display, (zx1, zy1), (zx2, zy2), color, 2)
    cv2.putText(
        display,
        "ALERT ZONE",
        (zx1 + 5, zy1 + 20),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.5,
        color,
        1,
    )


def draw_disarmed_overlay(display):
    overlay = display.copy()
    cv2.rectangle(overlay, (0, 0), (640, 480), (30, 30, 30), -1)
    cv2.addWeighted(overlay, 0.55, display, 0.45, 0, display)
    cv2.putText(
        display, "DISARMED", (170, 255), cv2.FONT_HERSHEY_SIMPLEX, 2.2, (100, 100, 100), 4
    )
    cv2.putText(
        display,
        "Arm the system from the app to start detection",
        (42, 310),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.52,
        (160, 160, 160),
        1,
    )


def draw_statusbar(display, persons, unknowns, night, armed):
    cv2.rectangle(display, (0, 0), (640, 40), (30, 30, 30), -1)
    timestamp = datetime.now().strftime("%H:%M:%S")
    night_txt = "NIGHT" if night else "DAY"
    arm_txt = "ARMED" if armed else "DISARMED"
    arm_color = (0, 255, 100) if armed else (100, 100, 100)
    cv2.putText(
        display,
        f"Smart Security v3  |  {timestamp}  |  {night_txt}  |  P:{persons}  |  UNK:{unknowns}",
        (8, 16),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.42,
        (255, 255, 255),
        1,
    )
    cv2.putText(
        display,
        arm_txt,
        (540, 30),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.55,
        arm_color,
        2,
    )


cmd = [
    "rpicam-vid",
    "--width",
    str(WIDTH),
    "--height",
    str(HEIGHT),
    "--framerate",
    "10",
    "--codec",
    "mjpeg",
    "--timeout",
    "0",
    "--nopreview",
    "-o",
    "-",
]

process = subprocess.Popen(
    cmd,
    stdout=subprocess.PIPE,
    stderr=subprocess.DEVNULL,
    bufsize=10**6,
)

log_event("Smart Security System Started")
print("\nCamera started!")
print("Press Q to quit")
print("-" * 45)

cv2.namedWindow("Smart Security v3.0", cv2.WINDOW_NORMAL)
cv2.resizeWindow("Smart Security v3.0", 640, 480)

buffer = b""
frame_count = 0
last_frame = None

while True:
    try:
        chunk = process.stdout.read(2048)
        if not chunk:
            break

        buffer += chunk
        if len(buffer) > 300000:
            buffer = buffer[-300000:]

        start = buffer.find(b"\xff\xd8")
        end = buffer.find(b"\xff\xd9")
        if start == -1 or end == -1:
            continue

        jpg = buffer[start : end + 2]
        buffer = buffer[end + 2 :]

        frame = cv2.imdecode(np.frombuffer(jpg, np.uint8), cv2.IMREAD_COLOR)
        if frame is None:
            continue

        try:
            requests.post(
                "http://localhost:5000/api/frame/update",
                data=jpg,
                timeout=0.1,
            )
        except Exception:
            pass

        frame_count += 1
        display = cv2.resize(frame, (640, 480))
        scale_x = 640 / WIDTH
        scale_y = 480 / HEIGHT
        night_mode = is_night_mode()
        alert_zone_on = False
        persons_found = 0

        if not local_state["armed"]:
            draw_disarmed_overlay(display)
            draw_statusbar(display, 0, unknown_count, night_mode, False)
            cv2.imshow("Smart Security v3.0", display)
            if cv2.waitKey(1) & 0xFF == ord("q"):
                break
            continue

        confidence_limit = int(local_state["confidence"] * 100)
        loiter_limit = int(local_state["loiter_sec"])
        if night_mode:
            loiter_limit = min(loiter_limit, 4)

        if frame_count % SKIP_FRAMES == 0:
            results = yolo_model(frame, verbose=False, imgsz=192)
            boxes = results[0].boxes
            gray_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            current_persons = []

            if boxes is not None:
                for box in boxes:
                    label_id = int(box.cls[0])
                    label = yolo_model.names[label_id]
                    conf = float(box.conf[0])

                    if label in IGNORE_LABELS:
                        x1, y1, x2, y2 = map(int, box.xyxy[0])
                        dx1 = int(x1 * scale_x)
                        dy1 = int(y1 * scale_y)
                        dx2 = int(x2 * scale_x)
                        dy2 = int(y2 * scale_y)
                        cv2.rectangle(display, (dx1, dy1), (dx2, dy2), (255, 255, 0), 2)
                        cv2.putText(
                            display,
                            f"{label} - ignored",
                            (dx1, dy1 - 8),
                            cv2.FONT_HERSHEY_SIMPLEX,
                            0.5,
                            (255, 255, 0),
                            1,
                        )
                        log_event(f"Animal ignored: {label}")
                        continue

                    if label != "person" or conf < 0.5:
                        continue

                    persons_found += 1
                    x1, y1, x2, y2 = map(int, box.xyxy[0])
                    dx1 = int(x1 * scale_x)
                    dy1 = int(y1 * scale_y)
                    dx2 = int(x2 * scale_x)
                    dy2 = int(y2 * scale_y)

                    person_id = f"{(x1 + x2) // 2}_{(y1 + y2) // 2}"
                    current_persons.append(person_id)
                    in_zone = in_alert_zone(x1, y1, x2, y2)

                    if in_zone:
                        alert_zone_on = True
                        if person_id not in person_tracker:
                            person_tracker[person_id] = time.time()
                            log_event("Person entered alert zone")

                        time_in_zone = time.time() - person_tracker[person_id]
                        if time_in_zone > loiter_limit:
                            log_event(f"LOITERING DETECTED! {time_in_zone:.0f}s in zone")
                            try:
                                requests.post(
                                    "http://localhost:5000/api/alerts/add",
                                    json={
                                        "type": "motion",
                                        "title": f"Loitering Detected {time_in_zone:.0f}s",
                                        "severity": "medium",
                                        "camera": "Pi Camera",
                                        "zone": "Door",
                                    },
                                    timeout=1,
                                )
                            except Exception:
                                pass
                            cv2.putText(
                                display,
                                f"LOITERING {time_in_zone:.0f}s",
                                (dx1, dy2 + 20),
                                cv2.FONT_HERSHEY_SIMPLEX,
                                0.6,
                                (0, 0, 255),
                                2,
                            )

                        person_crop = gray_frame[y1:y2, x1:x2]
                        if person_crop.size > 0:
                            faces = face_cascade.detectMultiScale(
                                person_crop,
                                scaleFactor=1.1,
                                minNeighbors=4,
                                minSize=(25, 25),
                            )
                            for (fx, fy, fw, fh) in faces:
                                face_roi = person_crop[fy : fy + fh, fx : fx + fw]
                                face_roi = cv2.resize(face_roi, (150, 150))
                                rid, confidence = recognizer.predict(face_roi)

                                ffx = int((x1 + fx) * scale_x)
                                ffy = int((y1 + fy) * scale_y)
                                ffw = int(fw * scale_x)
                                ffh = int(fh * scale_y)

                                if confidence < confidence_limit:
                                    name = label_map[rid]
                                    color = (0, 255, 0)
                                    text = f"Known: {name}"
                                    log_event(f"Known person: {name}")
                                    person_tracker.pop(person_id, None)
                                else:
                                    color = (0, 0, 255)
                                    text = "UNKNOWN"
                                    unknown_count += 1
                                    ts = datetime.now().strftime("%H-%M-%S")
                                    path = f"faces/unknown/unknown_{ts}.jpg"
                                    cv2.imwrite(path, frame)
                                    log_event(f"UNKNOWN DETECTED! Saved: {path}")
                                    try:
                                        requests.post(
                                            "http://localhost:5000/api/alerts/add",
                                            json={
                                                "type": "person",
                                                "title": "Unknown Person Detected",
                                                "severity": "high",
                                                "camera": "Pi Camera",
                                                "zone": "Door",
                                            },
                                            timeout=1,
                                        )
                                    except Exception:
                                        pass

                                cv2.rectangle(display, (ffx, ffy), (ffx + ffw, ffy + ffh), color, 2)
                                cv2.rectangle(display, (ffx, ffy - 28), (ffx + ffw, ffy), color, -1)
                                cv2.putText(
                                    display,
                                    text,
                                    (ffx + 4, ffy - 8),
                                    cv2.FONT_HERSHEY_SIMPLEX,
                                    0.5,
                                    (255, 255, 255),
                                    1,
                                )

                        time_in_zone = time.time() - person_tracker.get(person_id, time.time())
                        box_color = (0, 0, 255) if time_in_zone > loiter_limit else (0, 165, 255)
                    else:
                        box_color = (200, 200, 200)
                        person_tracker.pop(person_id, None)

                    cv2.rectangle(display, (dx1, dy1), (dx2, dy2), box_color, 2)
                    cv2.putText(
                        display,
                        f"Person {conf:.0%}",
                        (dx1, dy1 - 8),
                        cv2.FONT_HERSHEY_SIMPLEX,
                        0.45,
                        box_color,
                        1,
                    )

                if persons_found >= CROWD_ALERT_COUNT:
                    log_event(f"CROWD ALERT! {persons_found} persons detected!")
                    cv2.putText(
                        display,
                        f"CROWD! {persons_found} persons",
                        (180, 240),
                        cv2.FONT_HERSHEY_SIMPLEX,
                        0.9,
                        (0, 0, 255),
                        2,
                    )

            try:
                requests.post(
                    "http://localhost:5000/api/stats/update",
                    json={
                        "unknown_count": unknown_count,
                        "person_count": persons_found,
                        "last_event": f"Detected {persons_found} person(s)",
                    },
                    timeout=1,
                )
            except Exception:
                pass

            person_tracker = {k: v for k, v in person_tracker.items() if k in current_persons}

            del results
            gc.collect()
            last_frame = display.copy()
        elif last_frame is not None:
            display = last_frame.copy()

        draw_zone(display, alert_zone_on)
        draw_statusbar(display, persons_found, unknown_count, night_mode, local_state["armed"])

        cv2.imshow("Smart Security v3.0", display)
        if cv2.waitKey(1) & 0xFF == ord("q"):
            break

    except KeyboardInterrupt:
        break
    except Exception as e:
        log_event(f"Error: {e}")
        continue

process.terminate()
cv2.destroyAllWindows()
log_event(f"System stopped. Unknown count: {unknown_count}")
print("Goodbye!")
