import cv2
import numpy as np
import subprocess
import pickle
import os
import gc

print("Face Recognition System Starting...")

# Load Models
MODEL_PATH = "models/face_model.yml"
LABEL_PATH = "models/label_map.pkl"

if not os.path.exists(MODEL_PATH):
    print("No trained model found! Run face_train.py first")
    exit()

recognizer = cv2.face.LBPHFaceRecognizer_create()
recognizer.read(MODEL_PATH)

with open(LABEL_PATH, "rb") as f:
    label_map = pickle.load(f)

face_cascade = cv2.CascadeClassifier(
    cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
)

print("Model loaded!")
print("Known persons:", list(label_map.values()))

# Settings
WIDTH, HEIGHT = 320, 240
CONFIDENCE_LIMIT = 65

os.makedirs("faces/unknown", exist_ok=True)

# Camera
cmd = [
    "rpicam-vid",
    "--width", str(WIDTH),
    "--height", str(HEIGHT),
    "--framerate", "10",
    "--codec", "mjpeg",
    "--timeout", "0",
    "--nopreview",
    "-o", "-"
]

process = subprocess.Popen(
    cmd,
    stdout=subprocess.PIPE,
    stderr=subprocess.DEVNULL,
    bufsize=10**6
)

print("Camera started! Press Q to quit")
print("-" * 40)

cv2.namedWindow("Face Recognition", cv2.WINDOW_NORMAL)
cv2.resizeWindow("Face Recognition", 640, 480)

buffer = b""
frame_count = 0
unknown_count = 0

while True:
    try:
        chunk = process.stdout.read(2048)
        if not chunk:
            break

        buffer += chunk
        if len(buffer) > 300000:
            buffer = buffer[-300000:]

        start = buffer.find(b'\xff\xd8')
        end = buffer.find(b'\xff\xd9')

        if start == -1 or end == -1:
            continue

        jpg = buffer[start:end+2]
        buffer = buffer[end+2:]

        frame = cv2.imdecode(np.frombuffer(jpg, np.uint8), cv2.IMREAD_COLOR)
        if frame is None:
            continue

        frame_count += 1

        display = cv2.resize(frame, (640, 480))
        scale_x = 640 / WIDTH
        scale_y = 480 / HEIGHT

        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        faces = face_cascade.detectMultiScale(
            gray, 1.1, 5, minSize=(50, 50)
        )

        for (x, y, w, h) in faces:
            face_roi = gray[y:y+h, x:x+w]
            face_roi = cv2.resize(face_roi, (150, 150))

            label_id, confidence = recognizer.predict(face_roi)

            sx = int(x * scale_x)
            sy = int(y * scale_y)
            sw = int(w * scale_x)
            sh = int(h * scale_y)

            if confidence < CONFIDENCE_LIMIT:
                name = label_map[label_id]
                color = (0, 255, 0)
                text = f"{name} ({confidence:.0f})"
                print(f"Known: {name} | {confidence:.1f}")

            else:
                color = (0, 0, 255)
                text = f"Unknown ({confidence:.0f})"
                print("UNKNOWN PERSON DETECTED")

                # Save only every 20 frames
                if frame_count % 20 == 0:
                    unknown_count += 1
                    path = f"faces/unknown/unknown_{unknown_count}.jpg"
                    cv2.imwrite(path, face_roi)
                    print(f"Saved: {path}")

            cv2.rectangle(display, (sx, sy), (sx+sw, sy+sh), color, 3)

            cv2.putText(display, text,
                        (sx, sy-10),
                        cv2.FONT_HERSHEY_SIMPLEX,
                        0.6, color, 2)

        cv2.imshow("Face Recognition", display)
        gc.collect()

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
print(f"Unknown faces saved: {unknown_count}")
