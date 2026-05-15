import glob
import json
import os
import shutil
import subprocess
import sys
import threading
import time
from collections import deque
from datetime import datetime

import cv2
import numpy as np
from flask import Flask, Response, jsonify, request, send_from_directory
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

system_state = {
    "armed": False,
    "night_mode": False,
    "running": False,
    "unknown_count": 0,
    "person_count": 0,
    "last_event": None,
    "uptime": datetime.now().isoformat(),
    "sensitivity": 50,
    "confidence": 0.55,
    "loiter_sec": 9,
}

alerts_list = []
smart_process = None
latest_frame = {"data": None, "decoded": None, "timestamp": None}
frame_buffer = deque(maxlen=150)
recording_lock = threading.Lock()
last_recording_trigger_at = 0.0

PRE_RECORD_SECONDS = 4
POST_RECORD_SECONDS = 6
RECORDING_COOLDOWN_SECONDS = 8
MAX_RECORDINGS = 60
MAX_RECORDING_AGE_DAYS = 7
RECORDINGS_DIR = "recordings"
RECORDING_THUMBS_DIR = os.path.join(RECORDINGS_DIR, "thumbs")


def get_known_faces():
    known = []
    base = "faces/known"
    if not os.path.exists(base):
        return known

    for name in os.listdir(base):
        path = os.path.join(base, name)
        if not os.path.isdir(path):
            continue
        known.append(
            {
                "name": name,
                "photos": len(os.listdir(path)),
                "path": path,
            }
        )
    return known


def capture_face_samples(name, target_count=20, timeout_sec=30):
    person_dir = os.path.join("faces", "known", name)
    os.makedirs(person_dir, exist_ok=True)

    face_cascade = cv2.CascadeClassifier(
        cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
    )
    if face_cascade.empty():
        raise RuntimeError("Failed to load Haar cascade")

    saved = 0
    start_time = time.time()
    last_saved = 0.0

    while saved < target_count and time.time() - start_time < timeout_sec:
        frame_bytes = latest_frame["data"]
        if frame_bytes is None:
            time.sleep(0.1)
            continue

        frame = cv2.imdecode(np.frombuffer(frame_bytes, np.uint8), cv2.IMREAD_COLOR)
        if frame is None:
            time.sleep(0.1)
            continue

        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        faces = face_cascade.detectMultiScale(
            gray,
            scaleFactor=1.1,
            minNeighbors=5,
            minSize=(60, 60),
        )

        if len(faces) == 0:
            time.sleep(0.1)
            continue

        if time.time() - last_saved < 0.35:
            time.sleep(0.05)
            continue

        x, y, w, h = max(faces, key=lambda item: item[2] * item[3])
        face_img = gray[y : y + h, x : x + w]
        face_img = cv2.resize(face_img, (150, 150))
        filename = os.path.join(person_dir, f"{name}_{saved + 1:02d}.jpg")
        cv2.imwrite(filename, face_img)
        saved += 1
        last_saved = time.time()

    return saved


def save_uploaded_face_samples(name, uploaded_files):
    person_dir = os.path.join("faces", "known", name)
    os.makedirs(person_dir, exist_ok=True)

    face_cascade = cv2.CascadeClassifier(
        cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
    )
    if face_cascade.empty():
        raise RuntimeError("Failed to load Haar cascade")

    saved = 0
    for uploaded in uploaded_files:
        raw = uploaded.read()
        if not raw:
            continue

        image = cv2.imdecode(np.frombuffer(raw, np.uint8), cv2.IMREAD_COLOR)
        if image is None:
            continue

        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        faces = face_cascade.detectMultiScale(
            gray,
            scaleFactor=1.1,
            minNeighbors=5,
            minSize=(60, 60),
        )
        if len(faces) == 0:
            continue

        x, y, w, h = max(faces, key=lambda item: item[2] * item[3])
        face_img = gray[y : y + h, x : x + w]
        face_img = cv2.resize(face_img, (150, 150))
        filename = os.path.join(person_dir, f"{name}_mobile_{saved + 1:02d}.jpg")
        cv2.imwrite(filename, face_img)
        saved += 1

    return saved


def sync_running_state():
    global smart_process
    running = bool(smart_process and smart_process.poll() is None)
    if not running:
        smart_process = None
    system_state["running"] = running
    return running


def _format_duration(seconds):
    total_seconds = max(1, int(round(seconds)))
    minutes, secs = divmod(total_seconds, 60)
    return f"{minutes}:{secs:02d}"


def _format_file_size(num_bytes):
    size = float(num_bytes)
    for unit in ("B", "KB", "MB", "GB"):
        if size < 1024 or unit == "GB":
            if unit == "B":
                return f"{int(size)} {unit}"
            return f"{size:.1f} {unit}"
        size /= 1024.0


def _recording_metadata_path(filename):
    stem, _ = os.path.splitext(filename)
    return os.path.join(RECORDINGS_DIR, f"{stem}.json")


def cleanup_old_recordings():
    os.makedirs(RECORDINGS_DIR, exist_ok=True)
    os.makedirs(RECORDING_THUMBS_DIR, exist_ok=True)

    clips = [
        os.path.join(RECORDINGS_DIR, file_name)
        for file_name in os.listdir(RECORDINGS_DIR)
        if file_name.lower().endswith(".mp4")
    ]
    clips.sort(key=os.path.getmtime, reverse=True)

    now = time.time()
    keep = []
    purge = []
    for index, clip_path in enumerate(clips):
        clip_age_days = (now - os.path.getmtime(clip_path)) / 86400
        if index < MAX_RECORDINGS and clip_age_days <= MAX_RECORDING_AGE_DAYS:
            keep.append(clip_path)
        else:
            purge.append(clip_path)

    for clip_path in purge:
        filename = os.path.basename(clip_path)
        thumb_path = os.path.join(RECORDING_THUMBS_DIR, f"{os.path.splitext(filename)[0]}.jpg")
        meta_path = _recording_metadata_path(filename)
        for path in (clip_path, thumb_path, meta_path):
            if os.path.exists(path):
                os.remove(path)


def _create_recording_metadata(filename, alert):
    file_path = os.path.join(RECORDINGS_DIR, filename)
    thumb_name = f"{os.path.splitext(filename)[0]}.jpg"
    thumb_path = os.path.join(RECORDING_THUMBS_DIR, thumb_name)
    timestamp = datetime.fromtimestamp(os.path.getmtime(file_path))
    duration_seconds = float(alert.get("duration_seconds", 0.0))

    return {
        "id": os.path.splitext(filename)[0],
        "filename": filename,
        "cameraId": "pi_cam",
        "camera": alert.get("camera", "Pi Camera"),
        "date": timestamp.strftime("%b %d, %I:%M %p"),
        "duration": _format_duration(duration_seconds),
        "durationSeconds": round(duration_seconds, 1),
        "type": alert.get("type", "motion"),
        "thumb": f"/api/recordings/thumbs/{thumb_name}" if os.path.exists(thumb_path) else "",
        "zone": alert.get("zone", "Door"),
        "fileSize": _format_file_size(os.path.getsize(file_path)),
        "isFavourite": False,
        "isDownloaded": False,
        "alertId": alert.get("alert_id"),
        "timestamp": timestamp.isoformat(),
        "url": f"/api/recordings/{filename}",
    }


def _write_recording_metadata(filename, alert):
    meta = _create_recording_metadata(filename, alert)
    with open(_recording_metadata_path(filename), "w", encoding="utf-8") as handle:
        json.dump(meta, handle, indent=2)
    return meta


def _collect_recordings():
    cleanup_old_recordings()

    result = []
    for file_path in glob.glob(os.path.join(RECORDINGS_DIR, "*.mp4")):
        filename = os.path.basename(file_path)
        meta_path = _recording_metadata_path(filename)
        metadata = None
        if os.path.exists(meta_path):
            try:
                with open(meta_path, "r", encoding="utf-8") as handle:
                    metadata = json.load(handle)
            except Exception:
                metadata = None
        if metadata is None:
            metadata = _create_recording_metadata(
                filename,
                {"camera": "Pi Camera", "zone": "Door", "type": "motion"},
            )
        result.append(metadata)

    result.sort(key=lambda item: item.get("timestamp", ""), reverse=True)
    return result


def _record_event_clip(alert):
    prebuffer_start = time.time() - PRE_RECORD_SECONDS

    time.sleep(POST_RECORD_SECONDS)

    with recording_lock:
        buffered_frames = [
            (timestamp, frame.copy())
            for timestamp, frame in frame_buffer
            if timestamp >= prebuffer_start
        ]

    if len(buffered_frames) < 2:
        return

    first_frame = buffered_frames[0][1]
    height, width = first_frame.shape[:2]
    timestamp = datetime.now()
    filename = f"event_{timestamp.strftime('%Y%m%d_%H%M%S')}_{alert['type']}.mp4"
    file_path = os.path.join(RECORDINGS_DIR, filename)
    thumb_name = f"{os.path.splitext(filename)[0]}.jpg"
    thumb_path = os.path.join(RECORDING_THUMBS_DIR, thumb_name)

    writer = cv2.VideoWriter(
        file_path,
        cv2.VideoWriter_fourcc(*"mp4v"),
        10.0,
        (width, height),
    )

    written = 0
    for _, frame in buffered_frames:
        writer.write(frame)
        written += 1
    writer.release()

    if written < 2 or not os.path.exists(file_path) or os.path.getsize(file_path) == 0:
        if os.path.exists(file_path):
            os.remove(file_path)
        return

    thumb_frame = buffered_frames[min(len(buffered_frames) // 2, len(buffered_frames) - 1)][1]
    cv2.imwrite(thumb_path, thumb_frame)

    alert["duration_seconds"] = written / 10.0
    _write_recording_metadata(filename, alert)
    cleanup_old_recordings()


def trigger_smart_recording(alert):
    global last_recording_trigger_at

    if alert.get("type") not in {"person", "motion"}:
        return
    if latest_frame["decoded"] is None:
        return

    now = time.time()
    with recording_lock:
        if now - last_recording_trigger_at < RECORDING_COOLDOWN_SECONDS:
            return
        last_recording_trigger_at = now

    recording_alert = {
        "type": alert.get("type", "motion"),
        "camera": alert.get("camera", "Pi Camera"),
        "zone": alert.get("zone", "Door"),
        "alert_id": alert.get("id"),
    }
    worker = threading.Thread(
        target=_record_event_clip,
        args=(recording_alert,),
        daemon=True,
    )
    worker.start()


def _add_alert(type_, title, severity="medium", camera="Pi Camera", zone="Door"):
    alert = {
        "id": f"alert_{len(alerts_list) + 1}",
        "type": type_,
        "title": title,
        "subtitle": f"{title} detected at {camera}",
        "camera": camera,
        "zone": zone,
        "severity": severity,
        "isRead": False,
        "time": "Just now",
        "timestamp": datetime.now().isoformat(),
    }
    alerts_list.insert(0, alert)
    if len(alerts_list) > 100:
        alerts_list.pop()
    trigger_smart_recording(alert)


@app.route("/api/health", methods=["GET"])
def health():
    return jsonify(
        {
            "status": "online",
            "version": "3.0",
            "time": datetime.now().isoformat(),
        }
    )


@app.route("/api/status", methods=["GET"])
def status():
    sync_running_state()
    return jsonify(system_state)


@app.route("/api/arm", methods=["POST"])
def arm():
    data = request.get_json() or {}
    state = data.get("armed", False)
    system_state["armed"] = state
    event = "System Armed" if state else "System Disarmed"
    system_state["last_event"] = event
    _add_alert("system", event, "medium")
    return jsonify({"success": True, "armed": state})


@app.route("/api/nightmode", methods=["POST"])
def night_mode():
    data = request.get_json() or {}
    state = data.get("enabled", False)
    system_state["night_mode"] = state
    return jsonify({"success": True, "night_mode": state})


@app.route("/api/alerts", methods=["GET"])
def get_alerts():
    return jsonify(alerts_list)


@app.route("/api/alerts/clear", methods=["POST"])
def clear_alerts():
    alerts_list.clear()
    return jsonify({"success": True})


@app.route("/api/alerts/<alert_id>/read", methods=["POST"])
def mark_alert_read(alert_id):
    for alert in alerts_list:
        if alert["id"] == alert_id:
            alert["isRead"] = True
            return jsonify({"success": True})
    return jsonify({"success": False, "error": "Not found"}), 404


@app.route("/api/alerts/<alert_id>", methods=["DELETE"])
def delete_alert(alert_id):
    for index, alert in enumerate(alerts_list):
        if alert["id"] == alert_id:
            del alerts_list[index]
            return jsonify({"success": True})
    return jsonify({"success": False, "error": "Not found"}), 404


@app.route("/api/alerts/add", methods=["POST"])
def add_alert():
    data = request.get_json() or {}
    _add_alert(
        data.get("type", "motion"),
        data.get("title", "Alert"),
        data.get("severity", "medium"),
        data.get("camera", "Pi Camera"),
        data.get("zone", "Door"),
    )
    return jsonify({"success": True})


@app.route("/api/stats/update", methods=["POST"])
def update_stats():
    data = request.get_json() or {}
    system_state["unknown_count"] = data.get("unknown_count", system_state["unknown_count"])
    system_state["person_count"] = data.get("person_count", system_state["person_count"])
    system_state["last_event"] = data.get("last_event", system_state["last_event"])
    return jsonify({"success": True})


@app.route("/api/faces", methods=["GET"])
def get_faces():
    return jsonify(get_known_faces())


@app.route("/api/faces/<name>", methods=["DELETE"])
def delete_face(name):
    path = f"faces/known/{name}"
    if os.path.exists(path):
        shutil.rmtree(path)
        return jsonify({"success": True})
    return jsonify({"success": False, "error": "Not found"}), 404


@app.route("/api/faces/retrain", methods=["POST"])
def retrain_faces():
    try:
        train_result = subprocess.run(
            [sys.executable, "face_train.py"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=120,
            check=False,
        )
        if train_result.returncode != 0:
            return jsonify({"success": False, "error": "Training failed"}), 500

        _add_alert("system", "Face database retrained", "medium")
        return jsonify(
            {
                "success": True,
                "known_faces": len(get_known_faces()),
            }
        )
    except subprocess.TimeoutExpired:
        return jsonify({"success": False, "error": "Training timed out"}), 500
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/faces/register", methods=["POST"])
def register_face():
    name = str(request.form.get("name", "")).strip()
    if not name:
        return jsonify({"success": False, "error": "Name is required"}), 400

    safe_name = "".join(ch for ch in name if ch.isalnum() or ch in (" ", "_", "-")).strip()
    if not safe_name:
        return jsonify({"success": False, "error": "Invalid name"}), 400

    try:
        os.makedirs("faces/known", exist_ok=True)
        os.makedirs("models", exist_ok=True)

        uploaded_files = request.files.getlist("images")
        if not uploaded_files:
            return (
                jsonify(
                    {
                        "success": False,
                        "error": "No face images were uploaded",
                    }
                ),
                400,
            )

        person_dir = os.path.join("faces", "known", safe_name)
        if os.path.exists(person_dir):
            shutil.rmtree(person_dir)
        os.makedirs(person_dir, exist_ok=True)

        saved = save_uploaded_face_samples(safe_name, uploaded_files)
        if saved < 3:
            shutil.rmtree(person_dir, ignore_errors=True)
            return (
                jsonify(
                    {
                        "success": False,
                        "error": "Could not detect enough clear face images from the phone camera.",
                        "captured": saved,
                    }
                ),
                400,
            )

        train_result = subprocess.run(
            [sys.executable, "face_train.py"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=120,
            check=False,
        )
        if train_result.returncode != 0:
            return (
                jsonify(
                    {
                        "success": False,
                        "error": "Face samples captured but training failed",
                        "captured": saved,
                    }
                ),
                500,
            )

        _add_alert("system", f"Face registered: {safe_name}", "medium")
        return jsonify(
            {
                "success": True,
                "name": safe_name,
                "captured": saved,
                "trained": True,
                "source": "mobile",
            }
        )
    except subprocess.TimeoutExpired:
        return jsonify({"success": False, "error": "Training timed out"}), 500
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/unknowns", methods=["GET"])
def get_unknowns():
    files = glob.glob("faces/unknown/*.jpg")
    files.sort(reverse=True)
    result = []
    for file_path in files[:20]:
        result.append(
            {
                "filename": os.path.basename(file_path),
                "time": datetime.fromtimestamp(os.path.getmtime(file_path)).isoformat(),
            }
        )
    return jsonify(result)


@app.route("/api/logs", methods=["GET"])
def get_logs():
    log_file = "logs/security_log.txt"
    if not os.path.exists(log_file):
        return jsonify([])
    with open(log_file, "r") as f:
        lines = [line.strip() for line in f.readlines() if line.strip()]
    return jsonify(lines[-50:])


@app.route("/api/detection/start", methods=["POST"])
def start_detection():
    global smart_process
    if sync_running_state():
        return jsonify({"success": False, "error": "Already running"})

    smart_process = subprocess.Popen(
        [sys.executable, "smart_security.py"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    time.sleep(0.5)

    if not sync_running_state():
        return (
            jsonify(
                {
                    "success": False,
                    "error": "Detection process exited during startup",
                }
            ),
            500,
        )

    return jsonify({"success": True})


@app.route("/api/detection/stop", methods=["POST"])
def stop_detection():
    global smart_process
    if smart_process:
        smart_process.terminate()
        smart_process = None
    system_state["running"] = False
    return jsonify({"success": True})


@app.route("/api/stream")
def stream():
    def generate():
        last_sent = None
        while True:
            frame = latest_frame["data"]
            if frame and frame != last_sent:
                last_sent = frame
                yield (
                    b"--frame\r\n"
                    b"Content-Type: image/jpeg\r\n\r\n" + frame + b"\r\n"
                )
            else:
                time.sleep(0.1)

    return Response(generate(), mimetype="multipart/x-mixed-replace; boundary=frame")


@app.route("/api/snapshot", methods=["POST"])
def save_snapshot():
    try:
        os.makedirs("captures", exist_ok=True)
        ts = datetime.now().strftime("%H-%M-%S")
        filename = f"captures/snapshot_{ts}.jpg"

        if latest_frame["data"] is None:
            return jsonify(
                {
                    "success": False,
                    "error": "No frame available yet",
                }
            )

        with open(filename, "wb") as f:
            f.write(latest_frame["data"])

        return jsonify({"success": True, "filename": os.path.basename(filename)})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)})


@app.route("/api/frame/update", methods=["POST"])
def update_frame():
    latest_frame["data"] = request.data
    latest_frame["timestamp"] = time.time()

    frame = cv2.imdecode(np.frombuffer(request.data, np.uint8), cv2.IMREAD_COLOR)
    if frame is not None:
        latest_frame["decoded"] = frame
        with recording_lock:
            frame_buffer.append((latest_frame["timestamp"], frame))
    return jsonify({"success": True})


@app.route("/api/snapshots", methods=["GET"])
def get_snapshots():
    try:
        files = glob.glob("captures/*.jpg")
        files.sort(key=os.path.getmtime, reverse=True)
        result = []
        for file_path in files[:50]:
            filename = os.path.basename(file_path)
            timestamp = datetime.fromtimestamp(os.path.getmtime(file_path))
            result.append(
                {
                    "id": filename,
                    "filename": filename,
                    "url": f"/api/snapshots/{filename}",
                    "time": timestamp.strftime("%H:%M:%S"),
                    "date": timestamp.strftime("%Y-%m-%d"),
                    "timestamp": timestamp.isoformat(),
                    "type": "person" if "unknown" in filename else "snapshot",
                    "camera": "Pi Camera",
                    "size_kb": round(os.path.getsize(file_path) / 1024, 1),
                }
            )
        return jsonify(result)
    except Exception:
        return jsonify([])


@app.route("/api/snapshots/<filename>", methods=["GET"])
def serve_snapshot(filename):
    return send_from_directory("captures", filename)


@app.route("/api/snapshots/<filename>", methods=["DELETE"])
def delete_snapshot(filename):
    try:
        path = f"captures/{filename}"
        if os.path.exists(path):
            os.remove(path)
            return jsonify({"success": True})
        return jsonify({"success": False, "error": "Not found"}), 404
    except Exception as e:
        return jsonify({"success": False, "error": str(e)})


@app.route("/api/snapshot/latest")
def latest_frame_image():
    if latest_frame["data"] is not None:
        return Response(
            latest_frame["data"],
            mimetype="image/jpeg",
            headers={"Cache-Control": "no-cache"},
        )
    return jsonify({"error": "No frame yet"}), 404


@app.route("/api/recordings", methods=["GET"])
def get_recordings():
    try:
        return jsonify(_collect_recordings())
    except Exception:
        return jsonify([])


@app.route("/api/recordings/<filename>", methods=["GET"])
def serve_recording(filename):
    return send_from_directory(RECORDINGS_DIR, filename)


@app.route("/api/recordings/thumbs/<filename>", methods=["GET"])
def serve_recording_thumb(filename):
    return send_from_directory(RECORDING_THUMBS_DIR, filename)


@app.route("/api/recordings/<filename>", methods=["DELETE"])
def delete_recording(filename):
    try:
        clip_path = os.path.join(RECORDINGS_DIR, filename)
        thumb_path = os.path.join(
            RECORDING_THUMBS_DIR,
            f"{os.path.splitext(filename)[0]}.jpg",
        )
        meta_path = _recording_metadata_path(filename)

        if not os.path.exists(clip_path):
            return jsonify({"success": False, "error": "Not found"}), 404

        for path in (clip_path, thumb_path, meta_path):
            if os.path.exists(path):
                os.remove(path)

        return jsonify({"success": True})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


@app.route("/api/sensitivity", methods=["POST"])
def set_sensitivity():
    data = request.get_json() or {}
    level = data.get("level", 50)
    confidence = round(0.75 - (level / 100) * 0.40, 2)
    loiter_sec = round(15 - (level / 100) * 12)

    system_state["sensitivity"] = level
    system_state["confidence"] = confidence
    system_state["loiter_sec"] = loiter_sec

    return jsonify(
        {
            "success": True,
            "level": level,
            "confidence": confidence,
            "loiter_sec": loiter_sec,
        }
    )


@app.route("/api/sensitivity", methods=["GET"])
def get_sensitivity():
    return jsonify(
        {
            "level": system_state.get("sensitivity", 50),
            "confidence": system_state.get("confidence", 0.55),
            "loiter_sec": system_state.get("loiter_sec", 9),
        }
    )


@app.route("/api/zone", methods=["GET"])
def get_zone():
    try:
        with open("models/zone_config.json", "r") as f:
            return jsonify(json.load(f))
    except Exception:
        return jsonify({}), 404


if __name__ == "__main__":
    print("=" * 45)
    print("   SecureHome API Server v3.0")
    print("   Running on port 5000")
    print("=" * 45)
    os.makedirs("logs", exist_ok=True)
    os.makedirs("captures", exist_ok=True)
    os.makedirs(RECORDINGS_DIR, exist_ok=True)
    os.makedirs(RECORDING_THUMBS_DIR, exist_ok=True)
    os.makedirs("faces/known", exist_ok=True)
    os.makedirs("faces/unknown", exist_ok=True)
    cleanup_old_recordings()
    app.run(host="0.0.0.0", port=5000, debug=False, threaded=True)
