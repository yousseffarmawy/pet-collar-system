#include <Wire.h>
#include "MPU6050.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// --- الإعدادات الثابتة ---
#define BUZZER_PIN 2      // ملحوظة: لو الجهاز مش بيقوم (Boot)، غيره لـ GPIO 3
#define I2C_SDA 8
#define I2C_SCL 9
#define REPORTING_PERIOD_MS 1000

MPU6050 mpu;
int stepCount = 0;
float threshold = 17000; 
bool stepFlag = false;

BLECharacteristic *pCharacteristic;
bool deviceConnected = false;
uint32_t tsLastReport = 0;
volatile bool triggerBuzzer = false;
unsigned long buzzerStartTime = 0;

#define SERVICE_UUID        "12345678-1234-1234-1234-1234567890ab"
#define CHARACTERISTIC_UUID "abcd1234-5678-1234-5678-abcdef123456"

// استقبال أمر البازر من الموبايل بدون تأخير
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        String value = pCharacteristic->getValue(); 
        if (value.length() > 0 && (value[0] == '1' || value[0] == 1)) {
            triggerBuzzer = true;
        }
    }
};

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) { 
        deviceConnected = true; 
        Serial.println("Mobile Connected ✅"); 
    }
    void onDisconnect(BLEServer* pServer) { 
        deviceConnected = false; 
        Serial.println("Disconnected ❌");
        BLEDevice::startAdvertising(); // إعادة البث فوراً
    }
};

void setup() {
    Serial.begin(115200);
    pinMode(BUZZER_PIN, OUTPUT);
    digitalWrite(BUZZER_PIN, LOW);

    // تشغيل الـ I2C
    Wire.begin(I2C_SDA, I2C_SCL);
    Wire.setClock(400000); // سرعة I2C أعلى لاستجابة أسرع

    Serial.println("Initializing MPU6050...");
    mpu.initialize();
    if (mpu.testConnection()) {
        Serial.println("MPU6050: OK ✅");
    } else {
        Serial.println("MPU6050: FAIL ❌ Check SCL/SDA Pins");
    }

    // إعداد الـ BLE
    BLEDevice::init("CORBI_DEVICE");
    BLEServer *pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());

    BLEService *pService = pServer->createService(SERVICE_UUID);
    pCharacteristic = pService->createCharacteristic(
                        CHARACTERISTIC_UUID,
                        BLECharacteristic::PROPERTY_NOTIFY | 
                        BLECharacteristic::PROPERTY_WRITE |
                        BLECharacteristic::PROPERTY_READ
                      );

    pCharacteristic->addDescriptor(new BLE2902());
    pCharacteristic->setCallbacks(new MyCallbacks());

    pService->start();
    BLEDevice::startAdvertising();
    Serial.println("BLE Ready to Pair!");
}

void loop() {
    // 1. قراءة الحركة وحساب الخطوات (دائماً شغالة)
    int16_t ax, ay, az;
    mpu.getAcceleration(&ax, &ay, &az);
    
    // حساب الـ Magnitude (قوة الحركة)
    double magnitude = sqrt((double)ax*ax + (double)ay*ay + (double)az*az);

    if (magnitude > threshold && !stepFlag) {
        stepCount++;
        stepFlag = true;
        Serial.printf("Step Detected! Total: %d\n", stepCount);
    } else if (magnitude < (threshold - 2000)) {
        stepFlag = false;
    }

    // 2. إرسال البيانات للموبايل كل ثانية (لو متصل)
    if (deviceConnected && (millis() - tsLastReport > REPORTING_PERIOD_MS)) {
        char buffer[32];
        sprintf(buffer, "0,%d,0", stepCount); // صيغة الرد
        pCharacteristic->setValue(buffer);
        pCharacteristic->notify();
        tsLastReport = millis();
    }

    // 3. التحكم في البازر بدون تأخير (Non-blocking)
    if (triggerBuzzer) {
        if (buzzerStartTime == 0) {
            digitalWrite(BUZZER_PIN, HIGH);
            buzzerStartTime = millis();
        }
        if (millis() - buzzerStartTime > 200) { // زمارة لمدة 200 مللي ثانية
            digitalWrite(BUZZER_PIN, LOW);
            triggerBuzzer = false;
            buzzerStartTime = 0;
        }
    }
}