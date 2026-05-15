import cv2
import numpy as np
import subprocess
from ultralytics import YOLO
import gc

# -- Settings --------------------------------------
WIDTH, HEIGHT = 320, 240
SKIP_FRAMES   = 10
IMGSZ         = 192

print("Loading YOLO model...")
model = YOLO("models/yolov8n.pt")
print("Model loaded ?")

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

print("Camera started ?")
print("Detecting objects... Press Q to quit")
print("-" * 40)

buffer      = b""
frame_count = 0

cv2.namedWindow("AI Security", cv2.WINDOW_NORMAL)
cv2.resizeWindow("AI Security", 640, 480)

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

        # -- Run YOLO every Nth frame ---------------
        if frame_count % SKIP_FRAMES == 0:
            results = model(frame, verbose=False, imgsz=IMGSZ)
            boxes   = results[0].boxes
            frame   = results[0].plot()

            # Print detected objects in terminal
            if boxes is not None and len(boxes) > 0:
                detected = []
                for box in boxes:
                    label = model.names[int(box.cls[0])]
                    conf  = float(box.conf[0])
                    detected.append(f"{label} ({conf:.0%})")

                print("??  " + " | ".join(detected))
            else:
                print("??  No objects detected")

            del results
            gc.collect()

        # -- Display --------------------------------
        display = cv2.resize(frame, (640, 480))
        cv2.imshow("AI Security", display)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    except KeyboardInterrupt:
        break
    except Exception as e:
        print(f"Error: {e}")
        continue

process.terminate()
cv2.destroyAllWindows()
print("Stopped ?")
