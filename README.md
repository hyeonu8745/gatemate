# 🛡️ GateMate — AI 기반 스마트 안전 울타리 시스템

> **Raspberry Pi 4 + ESP32-CAM + TFLite MoveNet + Flutter**
> 개인 프로젝트 · 2025년 · 2학년 1학기 · 전시회 출품 및 시연 성공

---

## 📌 프로젝트 소개

사람 접근을 AI로 감지하고, 게이트를 자동 제어하는 **가정용 스마트 안전 울타리 시스템**이다.

기존 스마트 게이트 제품은 대부분 차량용·고정형으로, 실내에서 아동이나 반려동물을 보호하기 위한 용도로는 적합하지 않다. GateMate는 이 문제를 해결하기 위해 **Raspberry Pi 4(센서부)**와 **ESP32-CAM(게이트부)**을 Wi-Fi로 연동해 저비용으로 구현한 IoT 분산 시스템이다.

---

## 🛠 Tech Stack

| 분류 | 기술 |
| --- | --- |
| 게이트부 | C++, Arduino IDE, ESP32-CAM, AsyncWebServer, Ticker |
| 센서부 | Python, Flask, OpenCV, TensorFlow Lite (MoveNet) |
| 모바일 앱 | Flutter (Dart) |
| 통신 | Wi-Fi REST API (HTTP GET) |
| 하드웨어 | MG996R 서보모터, HC-SR04 초음파, PIR 센서, SW-420 진동 센서 |

---

## 🏗️ 시스템 구성

```
[Flutter 앱]
    ↕ REST API (HTTP)
[Raspberry Pi 4]  ←——— Wi-Fi ———→  [ESP32-CAM]
  · MoveNet AI 감지                   · 서보모터(MG996R) 제어
  · 초음파/PIR 센서 보조 감지           · 충격 센서(SW-420)
  · Flask 서버 (로그 제공)             · AsyncWebServer (HTTP API)
  · LED / 부저 경고
```

---

## 📁 프로젝트 구조

```
gatemate/
├── gate/
│   └── gate_controller.cpp     # ESP32-CAM 펌웨어 (서보 제어 + 충격 감지)
├── sensor/
│   └── sensor_server.py        # Raspberry Pi 서버 (AI 감지 + Flask)
├── app/
│   ├── main.dart               # Flutter 앱 메인 (게이트 제어 · 자동 모드)
│   ├── log_page.dart           # 감지 로그 목록 페이지
│   └── log_detail_page.dart    # 로그 상세 페이지
└── README.md
```

---

## ⚡ 주요 기능

| 기능 | 설명 |
| --- | --- |
| 🤖 AI 사람 감지 | MoveNet(TFLite) 관절 추적 + 초음파·PIR 센서 융합 |
| 🚪 게이트 자동 제어 | 사람 감지 시 자동 개폐, 수동 제어도 가능 |
| 📱 Flutter 앱 | 자동 모드 전환 · 수동 제어 · 감지 로그 조회 |
| ⚠️ 충격 감지 안전 로직 | 닫히는 중 충격 시 자동 재개방 + 센서부 자동 OFF |
| 📋 감지 로그 | Flask 서버에서 감지 이력 + 이미지 조회 |

---

## 🔧 핵심 구현

### 1. ISR 기반 충격 감지 + 비동기 서보 제어

`delay()` 대신 **Ticker 타이머**로 서보를 1도씩 비동기 이동해 loop() 블로킹 없이 다른 요청을 동시에 처리할 수 있다. 충격 센서는 **IRAM_ATTR 인터럽트**로 즉시 감지한다.

```cpp
// 인터럽트 전용 메모리에 적재 — 즉시 처리
void IRAM_ATTR shockISR() { shocked = true; }

// Ticker로 1도씩 비동기 이동
void stepMove() {
    currentAngle += (currentAngle < targetAngle) ? 1 : -1;
    gate.write(currentAngle);
    if (currentAngle == targetAngle) servoTicker.detach();
}
```

### 2. 장애 복구 로직

닫히는 중 충격이 감지되면 게이트를 즉시 재개방하고, Wi-Fi를 통해 라즈베리파이에 자동 모드 OFF 명령을 전송한다.

```cpp
if (shocked && isMoving && isClosing) {
    startOpen();           // 게이트 재개방
    notifySensorAutoOff(); // 센서부에 감지 중단 명령 전송
}
```

### 3. Flutter 앱 상태 동기화

5초 주기 Timer.periodic으로 자동 모드 상태를 폴링해 앱과 실제 하드웨어 상태를 동기화한다.

```dart
_timer = Timer.periodic(const Duration(seconds: 5), (_) => _pollAutoMode());
```

---

## 🔧 실행 방법

### 게이트부 (ESP32-CAM)

1. Arduino IDE에서 `gate/gate_controller.cpp` 열기
2. Wi-Fi SSID·비밀번호, 고정 IP 설정 수정

```cpp
const char* ssid     = "your_wifi_ssid";
const char* password = "your_wifi_password";
IPAddress   local_IP(192, 168, 1, 200);  // ESP32 고정 IP
```

3. ESP32-CAM 보드로 업로드

### 센서부 (Raspberry Pi 4)

```bash
pip install flask opencv-python tflite-runtime
python sensor/sensor_server.py
```

### Flutter 앱

1. `app/main.dart`에서 IP 주소 수정

```dart
static const piIp = '192.168.1.122:5000';   // Raspberry Pi IP
static const gateIp = '192.168.1.200';       // ESP32 IP
```

2. Flutter 빌드 및 실행

```bash
flutter pub get
flutter run
```

---

## 🔌 하드웨어 구성

### 센서부 (Raspberry Pi 4)

| 부품 | 역할 | 전원 |
| --- | --- | --- |
| Raspberry Pi 4 | 메인 제어기 + Flask 서버 | USB-C 5V |
| USB 웹캠 | 영상 입력 (MoveNet 추론) | USB |
| HC-SR04 | 초음파 거리 감지 | GPIO 5V |
| PIR 센서 | 적외선 움직임 감지 | GPIO 5V |
| LED + 부저 | 시각·청각 경고 | GPIO |

### 게이트부 (ESP32-CAM)

| 부품 | 역할 | 전원 |
| --- | --- | --- |
| ESP32-CAM | Wi-Fi 통신 + 제어 | DC 5V |
| MG996R | 서보모터 (게이트 개폐) | DC 5~6V |
| SW-420 | 진동·충격 감지 | GPIO |

---

## 📊 트러블슈팅

| 문제 | 원인 | 해결 |
| --- | --- | --- |
| 서보 제어 중 HTTP 요청 미처리 | `delay()` 블로킹 | Ticker 비동기 타이머로 전환 |
| 게이트 닫힘 중 물체 끼임 | 충격 감지 타이밍 지연 | ISR + IRAM_ATTR 즉시 처리 |
| 전시 환경 Wi-Fi 불안정 | 외부 네트워크 차단 | 스마트폰 핫스팟 + 고정 IP 설정 |
| 서보 토크 부족 | 모터 출력 한계 | MG996R 고토크 모터로 교체 |

---

## 🏆 성과

- ✅ MoveNet + 초음파·PIR 센서 융합 기반 사람 감지 정상 동작
- ✅ 게이트 자동 개폐 및 충격 감지 시 안전 재개방 동작 확인
- ✅ Flutter 앱에서 실시간 원격 제어 및 로그 조회 가능
- ✅ **전시회 현장 시연 성공**

---

> 📧 jihyeonu910@gmail.com · 🔗 [github.com/hyeonu8745](https://github.com/hyeonu8745)
