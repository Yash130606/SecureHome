import cv2
import numpy as np
import subprocess
import os
import time

# -- Settings --------------------------------------
WIDTH, HEIGHT    = 320, 240
SAVE_DIR         = "faces/known"
PHOTOS_PER_ANGLE = 10
os.makedirs(SAVE_DIR, exist_ok=True)

# -- Angles to capture -----------------------------
ANGLES = [
    {"name": "front",       "instruction": "Look STRAIGHT at camera"},
    {"name": "left",        "instruction": "Turn face SLIGHTLY LEFT"},
    {"name": "right",       "instruction": "Turn face SLIGHTLY RIGHT"},
    {"name": "up",          "instruction": "Tilt face SLIGHTLY UP"},
    {"name": "down",        "instruction": "Tilt face SLIGHTLY DOWN"},
    {"name": "tilt_left",   "instruction": "TILT head to LEFT shoulder"},
    {"name": "tilt_right",  "instruction": "TILT head to RIGHT shoulder"},
]

TOTAL_PHOTOS = len(ANGLES) * PHOTOS_PER_ANGLE

# -- Ask name ---------------------------------------
print("=" * 45)
print("   AI Security - Face Capture System")
print("=" * 45)
name = input("\nEnter person name: ").strip()

person_dir = os.path.join(SAVE_DIR, name)
os.makedirs(person_dir, exist_ok=True)

print(f"\nCapturing {TOTAL_PHOTOS} photos for: {name}")
print(f"{len(ANGLES)} angles x {PHOTOS_PER_ANGLE} photos each")
print("-" * 45)

# -- Start Camera -----------------------------------
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

face_cascade = cv2.CascadeClassifier(
    cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
)

cv2.namedWindow("Face Capture", cv2.WINDOW_NORMAL)
cv2.resizeWindow("Face Capture", 640, 480)

# -- Helper � draw progress panel ------------------
def draw_progress(display, angle_index, angle_count, total_count, instruction):

    cv2.rectangle(display, (0, 0), (640, 80), (30, 30, 30), -1)

    cv2.putText(display,
               f"{instruction}",
               (10, 30),
               cv2.FONT_HERSHEY_SIMPLEX,
               0.7, (0, 255, 255), 2)

    cv2.putText(display,
               f"Angle {angle_index+1}/{len(ANGLES)} | Photo {angle_count}/{PHOTOS_PER_ANGLE} | Total {total_count}/{TOTAL_PHOTOS}",
               (10, 65),
               cv2.FONT_HERSHEY_SIMPLEX,
               0.55, (200, 200, 200), 1)

    panel_y = 480 - (len(ANGLES) * 28) - 10
    cv2.rectangle(display, (0, panel_y - 10),
                 (640, 480), (30, 30, 30), -1)

    for i, angle in enumerate(ANGLES):
        y = panel_y + (i * 28)

        if i < angle_index:
            label = f"{angle['instruction']}  DONE {PHOTOS_PER_ANGLE}/{PHOTOS_PER_ANGLE}"
            color = (0, 255, 0)
        elif i == angle_index:
            label = f"{angle['instruction']}  -> {angle_count}/{PHOTOS_PER_ANGLE}"
            color = (0, 255, 255)
        else:
            label = f"{angle['instruction']}"
            color = (150, 150, 150)

        cv2.putText(display, label,
                   (15, y),
                   cv2.FONT_HERSHEY_SIMPLEX,
                   0.5, color, 1)

    return display

# -- Main Capture Loop ------------------------------
buffer      = b""
total_count = 0

for angle_index, angle in enumerate(ANGLES):

    angle_count = 0
    instruction = angle["instruction"]
    angle_name  = angle["name"]

    print(f"\nAngle {angle_index+1}/{len(ANGLES)}: {instruction}")
    print("Get ready in 3 seconds...")

    countdown_start = time.time()
    while time.time() - countdown_start < 3:
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
        frame  = cv2.imdecode(
            np.frombuffer(jpg, np.uint8),
            cv2.IMREAD_COLOR
        )
        if frame is None:
            continue

        display  = cv2.resize(frame, (640, 480))
        seconds  = 3 - int(time.time() - countdown_start)

        cv2.rectangle(display, (0, 0), (640, 480), (0, 0, 0), -1)
        cv2.putText(display,
                   instruction,
                   (30, 200),
                   cv2.FONT_HERSHEY_SIMPLEX,
                   0.9, (0, 255, 255), 2)
        cv2.putText(display,
                   f"Starting in {seconds}...",
                   (180, 280),
                   cv2.FONT_HERSHEY_SIMPLEX,
                   1.2, (255, 255, 255), 3)

        cv2.imshow("Face Capture", display)
        cv2.waitKey(1)
        
    while angle_count < PHOTOS_PER_ANGLE:
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
        frame  = cv2.imdecode(
            np.frombuffer(jpg, np.uint8),
            cv2.IMREAD_COLOR
        )
        if frame is None:
            continue

        gray  = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        faces = face_cascade.detectMultiScale(
            gray, scaleFactor=1.1,
            minNeighbors=5, minSize=(40, 40)
        )

        display = cv2.resize(frame, (640, 480))
        display = draw_progress(
            display, angle_index,
            angle_count, total_count, instruction
        )

        if len(faces) > 0:
            for (x, y, w, h) in faces:
                sx = int(x * (640/WIDTH))
                sy = int(y * (480/HEIGHT))
                sw = int(w * (640/WIDTH))
                sh = int(h * (480/HEIGHT))
                cv2.rectangle(display,
                             (sx, sy), (sx+sw, sy+sh),
                             (0, 255, 0), 2)

                face_img = gray[y:y+h, x:x+w]
                face_img = cv2.resize(face_img, (150, 150))
                filename = f"{person_dir}/{name}_{angle_name}_{angle_count+1}.jpg"
                cv2.imwrite(filename, face_img)

                angle_count += 1
                total_count += 1
                print(f"{angle_name} {angle_count}/{PHOTOS_PER_ANGLE}")
                time.sleep(0.4)
                break
        else:
            cv2.putText(display,
                       "No face detected - adjust position",
                       (80, 250),
                       cv2.FONT_HERSHEY_SIMPLEX,
                       0.7, (0, 0, 255), 2)

        cv2.imshow("Face Capture", display)
        if cv2.waitKey(1) & 0xFF == ord('q'):
            process.terminate()
            cv2.destroyAllWindows()
            exit()

    print(f"{angle_name} complete!")
    
    flash_start = time.time()
    while time.time() - flash_start < 1:
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
        frame  = cv2.imdecode(
            np.frombuffer(jpg, np.uint8),
            cv2.IMREAD_COLOR
        )
        if frame is None:
            continue
        display = cv2.resize(frame, (640, 480))
        cv2.rectangle(display, (0, 0), (640, 480),
                     (0, 255, 0), 20)
        cv2.putText(display,
                   f"{angle_name.upper()} COMPLETE!",
                   (150, 240),
                   cv2.FONT_HERSHEY_SIMPLEX,
                   1.2, (0, 255, 0), 3)
        cv2.imshow("Face Capture", display)
        cv2.waitKey(1)

process.terminate()
cv2.destroyAllWindows()

print("\n" + "=" * 45)
print(f"CAPTURE COMPLETE for {name}!")
print(f"Total photos saved: {total_count}")
print(f"Location: {person_dir}")
print("=" * 45)
print("\nNow run: python3 face_train.py")

