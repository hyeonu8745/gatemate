/**********************************************************

 *  ESP32-CAM 게이트부  ○ Smart Gate Controller v1.3

 *  - 서보: 부드러운 이동 (Ticker)  - 웹 UI (AsyncWebServer)

 *  - Shock Sensor: 닫히는 도중에만 반응 → 게이트 열기 + 센서부 OFF

 **********************************************************/

#include <WiFi.h>

#include <ESPAsyncWebServer.h>

#include <ESP32Servo.h>

#include <Ticker.h>

#include <HTTPClient.h>



/* ─────────── Wi-Fi 설정 ─────────── */

const char* ssid     = "jhw";

const char* password = "gusdn1025!";

IPAddress   local_IP(192,168,198,200);

IPAddress   gateway (192,168,198,1);

IPAddress   subnet  (255,255,255,0);

IPAddress   dns     (8,8,8,8);



/* ─────────── 핀 설정 ─────────── */

#define SHOCK_PIN 13

#define SERVO_PIN 14



/* ─────────── 서보 동작 파라미터 ─────────── */

#define OPEN_ANGLE   0

#define CLOSE_ANGLE 180

#define STEP_DEGREE  1

#define STEP_MS     15



/* ─────────── 센서부(라즈베리파이) 정보 ─────────── */

const char* SENSOR_IP   = "192.168.198.122";

const int   SENSOR_PORT = 5000;

const char* AUTO_OFF_PATH = "/auto_mode/off";



/* ─────────── 전역 객체 & 변수 ─────────── */

Servo gate;

Ticker servoTicker;

AsyncWebServer server(80);



volatile bool shocked   = false;   // ISR → loop 전달

bool     isMoving   = false;       // 서보 동작 중?

bool     isClosing  = false;       // 현재 방향이 닫힘?

int      currentAngle = OPEN_ANGLE;

int      targetAngle  = OPEN_ANGLE;



/* ─────────── 유틸: 센서부 자동 OFF ─────────── */

void notifySensorAutoOff() {

  HTTPClient http;

  String url = "http://" + String(SENSOR_IP) + ":" + String(SENSOR_PORT) + AUTO_OFF_PATH;

  http.setTimeout(1000);                // 1 s 타임아웃

  http.begin(url);

  int code = http.GET();

  Serial.printf("Sensor OFF req → %s (code %d)\n", url.c_str(), code);

  http.end();

}



/* ─────────── 서보를 1도씩 이동 ─────────── */

void stepMove() {

  if (currentAngle == targetAngle) {    // 목표 도달

    servoTicker.detach();

    isMoving  = false;

    isClosing = false;

    return;

  }

  currentAngle += (currentAngle < targetAngle) ? STEP_DEGREE : -STEP_DEGREE;

  gate.write(currentAngle);

}



/* ─────────── 충격 센서 ISR ─────────── */

void IRAM_ATTR shockISR() { shocked = true; }



/* ─────────── 웹 UI (간단 HTML) ─────────── */

void handleUI(AsyncWebServerRequest *req) {

  String html =

    "<!DOCTYPE html><html><head><meta charset='UTF-8'><title>Gate</title></head><body style='text-align:center;'>"

    "<h2>스마트 게이트</h2>"

    "<button style='font-size:20px;' onclick=\"fetch('/gate/open')\">열기</button><br><br>"

    "<button style='font-size:20px;' onclick=\"fetch('/gate/close')\">닫기</button><br><br>"

    "<p>현재 각도: " + String(currentAngle) + "°</p></body></html>";

  req->send(200, "text/html; charset=UTF-8", html);

}



/* ─────────── 열기/닫기 핸들러 ─────────── */

void startOpen() {

  targetAngle = OPEN_ANGLE;

  isMoving    = true;

  isClosing   = false;

  servoTicker.attach_ms(STEP_MS, stepMove);

}

void startClose() {

  targetAngle = CLOSE_ANGLE;

  isMoving    = true;

  isClosing   = true;

  servoTicker.attach_ms(STEP_MS, stepMove);

}

void handleOpen (AsyncWebServerRequest *r){ if(!isMoving) startOpen (); r->send(200,"text/plain","OPEN"); }

void handleClose(AsyncWebServerRequest *r){ if(!isMoving) startClose(); r->send(200,"text/plain","CLOSE"); }



void setup() {

  Serial.begin(115200);



  /* Wi-Fi 연결 */

  WiFi.mode(WIFI_STA);

  if (!WiFi.config(local_IP,gateway,subnet,dns))

    Serial.println("Static IP 실패 → DHCP");

  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) { delay(500); Serial.print("."); }

  Serial.printf("\nWiFi OK: %s\n", WiFi.localIP().toString().c_str());



  /* 서보 초기화 */

  gate.setPeriodHertz(50);

  gate.attach(SERVO_PIN, 500, 2500);

  gate.write(currentAngle);



  /* 충격 센서 */

  pinMode(SHOCK_PIN, INPUT);

  attachInterrupt(digitalPinToInterrupt(SHOCK_PIN), shockISR, RISING);



  /* 웹 서버 라우팅 */

  server.on("/",            HTTP_GET, handleUI);

  server.on("/gate/open",   HTTP_GET, handleOpen);

  server.on("/gate/close",  HTTP_GET, handleClose);

  server.onNotFound([](AsyncWebServerRequest *r){ r->send(404,"text/plain","404"); });

  server.begin();

  Serial.println("HTTP server started");

}



void loop() {

  /* 닫히는 중 + 충격 발생 시 */

  if (shocked && isMoving && isClosing) {

    shocked = false;

    Serial.println("⚠️ Shock while closing → reopen + sensor OFF");

    startOpen();                     // 게이트 다시 열기

    notifySensorAutoOff();           // 센서부 감지 중단

  }

}