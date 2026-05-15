import cv2
import numpy as np
import os
import pickle

print("Face Training Started...")

KNOWN_DIR = "faces/known"
MODEL_DIR = "models"
os.makedirs(MODEL_DIR, exist_ok=True)

face_cascade = cv2.CascadeClassifier(
    cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
)

faces = []
labels = []
label_map = {}
current_id = 0

# Load all face images
print("\nLoading face images...")

for person_name in os.listdir(KNOWN_DIR):
    person_path = os.path.join(KNOWN_DIR, person_name)

    if not os.path.isdir(person_path):
        continue

    label_map[current_id] = person_name
    print(f"Found person: {person_name} (ID: {current_id})")

    count = 0

    for img_file in os.listdir(person_path):
        img_path = os.path.join(person_path, img_file)
        img = cv2.imread(img_path, cv2.IMREAD_GRAYSCALE)

        if img is None:
            continue

        img = cv2.resize(img, (150, 150))
        faces.append(img)
        labels.append(current_id)
        count += 1

    print(f"   Loaded {count} photos")
    current_id += 1

print(f"\nTotal images loaded: {len(faces)}")
print(f"Total persons: {len(label_map)}")

if len(faces) == 0:
    print("No faces found! Run face_capture.py first")
    exit()

# Train LBPH Model
print("\nTraining LBPH model...")

recognizer = cv2.face.LBPHFaceRecognizer_create()
recognizer.train(faces, np.array(labels))

# Save Model
model_path = os.path.join(MODEL_DIR, "face_model.yml")
recognizer.save(model_path)

# Save label map
label_path = os.path.join(MODEL_DIR, "label_map.pkl")
with open(label_path, "wb") as f:
    pickle.dump(label_map, f)

print(f"\nModel saved: {model_path}")
print(f"Labels saved: {label_path}")

print("\nTraining Complete!")
print("=" * 40)
for id, name in label_map.items():
    print(f"ID {id} -> {name}")
print("=" * 40)

print("\nNow run: python3 face_recognition_live.py")
