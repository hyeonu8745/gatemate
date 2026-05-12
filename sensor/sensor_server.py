센서부



from flask import Flask, jsonify

import RPi.GPIO as GPIO, cv2, time, json, threading, requests, os

import numpy as np

import tflite_runtime.interpreter as tflite

from datetime import datetime



# ─── 설정 ───

PIR_PIN = 17

TRIG_PIN = 23

ECHO_PIN = 24

GATE_IP = "192.168.198.200"

CAM_INDEX = 0

DIST_TH_CM = 200

RECHECK_SEC = 2

LOG_DIR = "logs"

os.makedirs(LOG_DIR, exist_ok=True)

LOG_FILE = os.path.join(LOG_DIR, "logs.json")



# ─── GPIO ───

GPIO.setwarnings(False)

GPIO.setmode(GPIO.BCM)

GPIO.setup(PIR_PIN, GPIO.IN)

GPIO.setup(TRIG_PIN, GPIO.OUT, initial=False)

GPIO.setup(ECHO_PIN, GPIO.IN)



# ─── Pose 모델 로딩 ───

interpreter = tflite.Interpreter(model_path="movenet_lightning.tflite")

interpreter.allocate_tensors()

in_det = interpreter.get_input_details()

out_det = interpreter.get_output_details()

IN_H, IN_W = in_det[0]['shape'][1:3]



# ─── 상태 변수 ───

auto_mode = False

is_closed = False

last_check = 0



# ─── 사람 인식 ───

def person_detected(frame) -> bool:

    img = cv2.resize(frame, (IN_W, IN_H))

    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    img = img.astype(np.uint8)[None] if in_det[0]['dtype'] == np.uint8 else (img.astype(np.float32)[None] / 255.0)

    interpreter.set_tensor(in_det[0]['index'], img)

    interpreter.invoke()

    conf = interpreter.get_tensor(out_det[0]['index'])[..., 2]

    return np.mean(conf > .5) > .5   # ▶ 더 신뢰도 높게



# ─── 거리 측정 (3회 평균) ───

def measure_cm(timeout=0.03) -> float:

    GPIO.output(TRIG_PIN, True)

    time.sleep(1e-5)

    GPIO.output(TRIG_PIN, False)

    start = time.time()

    while GPIO.input(ECHO_PIN) == 0 and time.time() - start < timeout:

        pass

    pulse_start = time.time()

    while GPIO.input(ECHO_PIN) == 1 and time.time() - pulse_start < timeout:

        pass

    pulse_end = time.time()

    duration = pulse_end - pulse_start

    return duration * 17150 if duration < timeout else 9999.0



def stable_distance():

    return sum([measure_cm() for _ in range(3)]) / 3.0



# ─── 게이트 제어 ───

def gate_close():

    try:

        r = requests.get(f"http://{GATE_IP}/gate/close", timeout=2)

        print("[GATE] CLOSE:", r.status_code)

    except Exception as e:

        print("[ERROR] Gate close failed:", e)



def gate_open():

    try:

        r = requests.get(f"http://{GATE_IP}/gate/open", timeout=2)

        print("[GATE] OPEN:", r.status_code)

    except Exception as e:

        print("[ERROR] Gate open failed:", e)



# ─── 로그 저장 ───

def add_log(msg, frame=None):

    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    img_url = ""

    if frame is not None:

        fname = f"{datetime.now():%Y%m%d_%H%M%S}.jpg"

        path = os.path.join(LOG_DIR, fname)

        cv2.imwrite(path, frame)

        img_url = f"/static/{fname}"

    entry = {"time": ts, "message": msg, "image_url": img_url}

    try:

        data = json.load(open(LOG_FILE))

    except:

        data = []

    data.insert(0, entry)

    json.dump(data, open(LOG_FILE, "w"))

    print("[LOG]", msg)



# ─── 자동 감지 루프 ───

def auto_loop():

    global auto_mode, is_closed, last_check

    cam = None

    print("[INFO] auto_loop 시작됨")



    while True:

        try:

            if not auto_mode:

                time.sleep(1)

                continue



            if cam is None or not cam.isOpened():

                cam = cv2.VideoCapture(CAM_INDEX)

                if not cam.isOpened():

                    print("❌ 카메라 열기 실패")

                    time.sleep(3)

                    continue



            # ── 접근 감지 시 게이트 닫기 ──

            if not is_closed and GPIO.input(PIR_PIN):

                ret, frame = cam.read()

                if not ret:

                    continue

                dist = stable_distance()

                if dist < DIST_TH_CM and person_detected(frame):

                    add_log(f"Approach {dist:.1f} cm", frame)

                    gate_close()

                    is_closed = True

                    last_check = time.time()

                    print("[INFO] 게이트 닫힘")

                time.sleep(0.2)

                continue



            # ── 닫힌 상태 → 사람 사라짐 확인 ──

            if is_closed and time.time() - last_check >= RECHECK_SEC:

                last_check = time.time()

                ret, frame = cam.read()

                if not ret:

                    continue

                dist = stable_distance()

                person = person_detected(frame)

                print(f"[RECHECK] dist={dist:.1f}, person={person}")

                if dist > (DIST_TH_CM + 30) and not person:

                    gate_open()

                    is_closed = False

                    add_log("Person gone, gate reopened")

                else:

                    print("[INFO] 계속 근처에 있음 → 닫힘 유지")

            time.sleep(0.2)



        except Exception as e:

            print("[ERROR] auto_loop 에러:", e)

            if cam:

                cam.release()

                cam = None

            time.sleep(5)



# ─── Flask API ───

app = Flask(__name__, static_folder=LOG_DIR, static_url_path="/static")



@app.route("/auto_mode/on")

def auto_on():

    global auto_mode

    auto_mode = True

    add_log("✅ 자동 감지 모드 ON")

    return "ON"



@app.route("/auto_mode/off")

def auto_off():

    global auto_mode

    auto_mode = False

    add_log("⏹️ 자동 감지 모드 OFF")

    return "OFF"



@app.route("/auto_mode/status")

def status():

    return jsonify({"auto_mode": auto_mode})



@app.route("/logs")

def logs():

    try:

        data = json.load(open(LOG_FILE))

    except:

        data = []

    return jsonify(data)



if __name__ == "__main__":

    threading.Thread(target=auto_loop, daemon=True).start()

    print("[INFO] Flask 서버 실행 중 (0.0.0.0:5000)")

    app.run(host="0.0.0.0", port=5000)