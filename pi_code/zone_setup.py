import cv2
import numpy as np
import subprocess
import json
import os

print("=" * 45)
print("   Zone Setup Tool")
print("   Draw your ALERT ZONE on screen")
print("=" * 45)
print("\nInstructions:")
print("Click TOP-LEFT of door area")
print("Click BOTTOM-RIGHT of door area")
print("Press S to save zone")
print("Press R to reset and redraw")
print("Press Q to quit")
print("-" * 45)

# -- Start Camera -----------------------------------
WIDTH, HEIGHT = 320, 240

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

# -- Mouse callback ---------------------------------
points   = []
zone_set = False

def mouse_click(event, x, y, flags, param):
    global points, zone_set
    if event == cv2.EVENT_LBUTTONDOWN:
        if len(points) < 2:
            points.append((x, y))
            print(f"Point {len(points)}: ({x}, {y})")
        if len(points) == 2:
            zone_set = True
            print(f"\nZone defined!")
            print(f"   Top-Left:     {points[0]}")
            print(f"   Bottom-Right: {points[1]}")
            print("Press S to save | R to redraw")

cv2.namedWindow("Zone Setup", cv2.WINDOW_NORMAL)
cv2.resizeWindow("Zone Setup", 640, 480)
cv2.setMouseCallback("Zone Setup", mouse_click)

buffer = b""

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

        display = cv2.resize(frame, (640, 480))

        # Draw instructions
        cv2.rectangle(display, (0, 0), (640, 35), (30, 30, 30), -1)
        cv2.putText(display,
                   "Click TOP-LEFT then BOTTOM-RIGHT of door area",
                   (10, 23),
                   cv2.FONT_HERSHEY_SIMPLEX,
                   0.55, (0, 255, 255), 1)

        # Draw points
        for i, pt in enumerate(points):
            cv2.circle(display, pt, 6, (0, 255, 0), -1)
            cv2.putText(display,
                       f"P{i+1}",
                       (pt[0]+8, pt[1]),
                       cv2.FONT_HERSHEY_SIMPLEX,
                       0.5, (0, 255, 0), 1)
       # Draw zone rectangle
        if len(points) == 2:
            cv2.rectangle(display,
                         points[0], points[1],
                         (0, 0, 255), 2)

            overlay = display.copy()
            cv2.rectangle(overlay,
                         points[0], points[1],
                         (0, 0, 255), -1)
            cv2.addWeighted(overlay, 0.25, display, 0.75, 0, display)

            cv2.putText(display,
                       "ALERT ZONE",
                       (points[0][0]+5, points[0][1]+25),
                       cv2.FONT_HERSHEY_SIMPLEX,
                       0.7, (0, 0, 255), 2)

        cv2.imshow("Zone Setup", display)

        key = cv2.waitKey(1) & 0xFF

         # Save zone
        if key == ord('s') and len(points) == 2:
            scale_x = WIDTH / 640
            scale_y = HEIGHT / 480

            zone = {
                "x1": int(points[0][0] * scale_x),
                "y1": int(points[0][1] * scale_y),
                "x2": int(points[1][0] * scale_x),
                "y2": int(points[1][1] * scale_y),
                "display_x1": points[0][0],
                "display_y1": points[0][1],
                "display_x2": points[1][0],
                "display_y2": points[1][1]
            }
            
            os.makedirs("models", exist_ok=True)
            with open("models/zone_config.json", "w") as f:
                json.dump(zone, f, indent=2)

            print("\nZone saved to models/zone_config.json")
            print(zone)
            print("\nNow run: python3 smart_security.py")
            break

        elif key == ord('r'):
            points   = []
            zone_set = False
            print("Reset -- click again")

        elif key == ord('q'):
            break

    except KeyboardInterrupt:
        break
        
process.terminate()
cv2.destroyAllWindows()
print("Zone setup complete")

           
