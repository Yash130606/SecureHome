import cv2
import numpy as np
import subprocess
import pickle
import os
import gc
from ultralytics import YOLO
from datetime import datetime

print("=" * 45)
print("   AI Security System v2.0")
print("   YOLO + Face Recognition")
print("=" * 45)

# ── Load Models ────────────────────────────────────
print("\nLoading models...")

yolo_model = YOLO("models/yolov8n.pt")
print("YOLO loaded!")

recognizer = cv2.face.LBPHFaceRecognizer_create()
recognizer.read("models/face_model.yml")
print("Face model loaded!")

with open("models/label_map.pkl", "rb") as f:
    label_map = pickle.load(f)
print("Known persons:", list(label_map.values()))

face_cascade = cv2.CascadeClassifier(
    cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
)

# ── Settings ───────────────────────────────────────
WIDTH, HEIGHT      = 320, 240
CONFIDENCE_LIMIT   = 70
SKIP_FRAMES        = 8
os.makedirs("faces/unknown", exist_ok=True)
os.makedirs("captures", exist_ok=True)

# ── Start Camera ───────────────────────────────────
cmd = [
    "rpicam-vid",
    "--width",     str(WIDTH),
    "--height",    str(HEIGHT),
    "--framerate", "10",
    "--codec",     "mjpeg",
    "--timeout",   "0",
    "--nopreview",
    "-o", "-"
]

process = subprocess.Popen(
    cmd,
    stdout=subprocess.PIPE,
    stderr=subprocess.DEVNULL,
    bufsize=10**6
)

print("\nCamera started!")
print("Press Q to quit")
print("-" * 45)

cv2.namedWindow("AI Security v2.0", cv2.WINDOW_NORMAL)
cv2.resizeWindow("AI Security v2.0", 640, 480)

buffer        = b""
frame_count   = 0
unknown_count = 0
last_frame    = None

# ── Helper — Draw Status Bar ───────────────────────
def draw_statusbar(display, persons_found, unknown_found):
    cv2.rectangle(display, (0, 0), (640, 35), (30, 30, 30), -1)
    timestamp = datetime.now().strftime("%H:%M:%S")
    cv2.putText(display,
               f"AI Security | {timestamp} | Person {persons_found} | Unknown {unknown_found}",
               (8, 24),
               cv2.FONT_HERSHEY_SIMPLEX,
               0.5, (255, 255, 255), 1)

# ── Main Loop ──────────────────────────────────────
while True:
    try:
        chunk = process.stdout.read(2048)
        if not chunk:
            break

        buffer += chunk
        if len(buffer) > 300000:
            buffer = buffer[-300000:]

        start = buffer.find(b'\xff\xd8')
        end   = buffer.find(b'\xff\xd9')
        if start == -1 or end == -1:
            continue

        jpg    = buffer[start:end+2]
        buffer = buffer[end+2:]

        frame = cv2.imdecode(
            np.frombuffer(jpg, np.uint8),
            cv2.IMREAD_COLOR
        )
        if frame is None:
            continue

        frame_count += 1
        display     = cv2.resize(frame, (640, 480))
        scale_x     = 640 / WIDTH
        scale_y     = 480 / HEIGHT
        persons_found = 0

        # ── Run YOLO every Nth frame ───────────────
        if frame_count % SKIP_FRAMES == 0:

            results     = yolo_model(frame, verbose=False, imgsz=192)
            boxes       = results[0].boxes
            gray_frame  = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

            if boxes is not None:
                for box in boxes:
                    label_id = int(box.cls[0])
                    label    = yolo_model.names[label_id]
                    conf     = float(box.conf[0])

                    if label != "person" or conf < 0.5:
                        continue

                    persons_found += 1

                    x1, y1, x2, y2 = map(int, box.xyxy[0])

                    dx1 = int(x1 * scale_x)
                    dy1 = int(y1 * scale_y)
                    dx2 = int(x2 * scale_x)
                    dy2 = int(y2 * scale_y)

                    person_crop = gray_frame[y1:y2, x1:x2]

                    if person_crop.size == 0:
                        continue

                    faces = face_cascade.detectMultiScale(
                        person_crop,
                        scaleFactor=1.1,
                        minNeighbors=4,
                        minSize=(30, 30)
                    )

                    face_found = False

                    for (fx, fy, fw, fh) in faces:
                        face_found = True
                        face_roi   = person_crop[fy:fy+fh, fx:fx+fw]
                        face_roi   = cv2.resize(face_roi, (150, 150))

                        rid, confidence = recognizer.predict(face_roi)

                        if confidence < CONFIDENCE_LIMIT:
                            name  = label_map[rid]
                            color = (0, 255, 0)
                            text  = f"{name}"
                            print(f"Known: {name} | conf: {confidence:.1f}")

                        else:
                            color     = (0, 0, 255)
                            text      = "UNKNOWN"
                            unknown_count += 1
                            print(f"UNKNOWN DETECTED! conf: {confidence:.1f}")

                            ts   = datetime.now().strftime("%H-%M-%S")
                            path = f"faces/unknown/unknown_{ts}.jpg"
                            cv2.imwrite(path, frame)
                            print(f"Saved: {path}")

                        ffx = int((x1 + fx) * scale_x)
                        ffy = int((y1 + fy) * scale_y)
                        ffw = int(fw * scale_x)
                        ffh = int(fh * scale_y)

                        cv2.rectangle(display,
                                     (ffx, ffy),
                                     (ffx+ffw, ffy+ffh),
                                     color, 2)

                        cv2.rectangle(display,
                                     (ffx, ffy-30),
                                     (ffx+ffw, ffy),
                                     color, -1)

                        cv2.putText(display, text,
                                   (ffx+4, ffy-10),
                                   cv2.FONT_HERSHEY_SIMPLEX,
                                   0.55, (255, 255, 255), 1)

                    person_color = (0, 255, 0) if face_found else (255, 165, 0)
                    cv2.rectangle(display,
                                 (dx1, dy1), (dx2, dy2),
                                 person_color, 2)

                    cv2.putText(display,
                               f"Person {conf:.0%}",
                               (dx1, dy1-8),
                               cv2.FONT_HERSHEY_SIMPLEX,
                               0.5, person_color, 1)

            del results
            gc.collect()
            last_frame = display.copy()

        else:
            if last_frame is not None:
                display = last_frame.copy()

        draw_statusbar(display, persons_found, unknown_count)

        cv2.imshow("AI Security v2.0", display)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    except KeyboardInterrupt:
        break
    except Exception as e:
        print(f"Error: {e}")
        continue

process.terminate()
cv2.destroyAllWindows()
print("\nSystem stopped.")
print(f"Unknown faces detected: {unknown_count}")
print("Goodbye!")
