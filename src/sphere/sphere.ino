#include <Wire.h>
#include <math.h>
#include <Adafruit_MotorShield.h>
#include <SparkFunLSM6DS3.h>
#include <Filters.h>
#include <SPI.h>
#include <WiFiNINA.h>
#include <WiFiUdp.h>

// GEAR STEPPER MOTOR
const int GER_COG = 600;
const int STP_COG = 200;

int stp_steps_fast = 1;
int stp_speed_fast_max = 20;
int stp_speed_fast_min = 12;
int stp_speed_fast_lim = 50;
int stp_speed_fast_set = 0;
float stp_speed_fast_incr;

int stp_steps_slow = 1;
int stp_speed_slow_set = 12;

int stp_steps_demo = 50;
int stp_speed_demo = 12;
int stp_steps_demo_delay = 10000;

int stp_cnt = 0;
int stp_cnt_safe;
int stp_tol = 6;
int stp_yaw, stp_yaw_left, stp_yaw_rght;
float stp_rpm;

Adafruit_MotorShield AFMS = Adafruit_MotorShield();
Adafruit_StepperMotor *STEPPER = AFMS.getStepper(STP_COG, 2);

// FAN DC MOTOR
Adafruit_DCMotor *FAN = AFMS.getMotor(1);
int fan_speed = 255;

// CONTROL ELEMENTS
constexpr auto TGL_PIN_AUTO = 13;
constexpr auto TGL_PIN_DEMO = 12;

unsigned long time, time_a, time_b, time_delta;
unsigned long time_run = 60000;

bool run_time = false;
bool run_auto = false;
bool run_demo = false;
bool run_udp = false;
bool run_fan = false;

// WLAN
int status = WL_IDLE_STATUS;
#include "ssid.h"
char ssid[] = SECRET_SSID;
char pass[] = SECRET_PASS;
unsigned int localPort = 2390;
char packetBuffer[255];								 // buffer to hold incoming packet
char ReplyBuffer[] = "acknowledged";   // string to send back
char stream_udp[255];
String stream_val;
WiFiUDP Udp;

// IMU
LSM6DS3 IMU(SPI_MODE, SPIIMU_SS);

float filterFrequency = 0.4;
FilterOnePole lowpass_x(LOWPASS, filterFrequency);
FilterOnePole lowpass_y(LOWPASS, filterFrequency);
FilterOnePole lowpass_z(LOWPASS, filterFrequency);

float aclr_x_val, aclr_y_val, aclr_z_val;
float angle_x, angle_x_val;
float angle_y, angle_y_val;
float angle_u, mgni_u;

// STREAM
String stream;
const int FCTR = 1;

void setup() {
	Serial.begin(9600);
	if (run_udp) {
		IMU.begin();
		delay(500);
		udpSetup();
	}

	pinMode(TGL_PIN_AUTO, INPUT);
	pinMode(TGL_PIN_DEMO, INPUT);

	AFMS.begin();
	FAN->setSpeed(fan_speed);
	FAN->run(RELEASE);
	stp_speed_fast_incr = float(stp_speed_fast_max - stp_speed_fast_min) / float(GER_COG / 2 - stp_speed_fast_lim); // calculate increase stepper
}

void loop() {
	if (run_udp) {
		accelerometer();
		data();
		udp();
	}
	control();
	stepper();
	if (run_fan) {
		fan();
	}
}

void udpSetup() {
	while (!Serial) {
		; // wait for serial port to connect. Needed for native USB port only
	}

	// check for the WiFi module
	if (WiFi.status() == WL_NO_MODULE) {
		Serial.println("Communication with WiFi module failed!");
		while (true); // don't continue
	}

	String fv = WiFi.firmwareVersion();
	if (fv < "1.0.0") {
		Serial.println("Please upgrade the firmware.");
	}

	while (status != WL_CONNECTED) {
		Serial.print("Attempting to connect to SSID: ");
		Serial.println(ssid);
		status = WiFi.begin(ssid, pass);
		delay(10000);
	}

	Serial.println("Connected to wifi.");
	printWifiStatus();

	Serial.println("\nStarting connection to server...");
	Udp.begin(localPort); // if you get a connection, report back via serial
}

void udp() {
	int packetSize = Udp.parsePacket();
	if (packetSize) {
		Serial.print("Received packet of size ");
		Serial.println(packetSize);
		Serial.print("From ");
		IPAddress remoteIp = Udp.remoteIP();
		Serial.print(remoteIp);
		Serial.print(", port ");
		Serial.println(Udp.remotePort());

		// read the packet into packetBufffer
		int len = Udp.read(packetBuffer, 255);
		if (len > 0) {
			packetBuffer[len] = 0;
		}
		Serial.println("Contents:");
		Serial.println(packetBuffer);

		// send a reply, to the IP address and port that sent us the packet we received
		Udp.beginPacket(Udp.remoteIP(), Udp.remotePort());
		Udp.write(ReplyBuffer);
		Udp.endPacket();
	}

	Udp.beginPacket(Udp.remoteIP(), Udp.remotePort());
	Udp.write(stream_udp, stream.length() + 1);
	Udp.endPacket();
}

void printWifiStatus() {
	Serial.print("SSID: ");
	Serial.println(WiFi.SSID());

	IPAddress ip = WiFi.localIP();
	Serial.print("IP Address: ");
	Serial.println(ip);

	long rssi = WiFi.RSSI();
	Serial.print("signal strength (RSSI):");
	Serial.print(rssi);
	Serial.println(" dBm");
}

void accelerometer() {
	aclr_x_val = IMU.readFloatAccelX();
	aclr_y_val = IMU.readFloatAccelY();
	aclr_z_val = IMU.readFloatAccelZ();

	aclr_x_val = lowpass_x.input(aclr_x_val);   // low pass filter x-axis
	aclr_y_val = lowpass_y.input(aclr_y_val);   // low pass filter y-axis
	aclr_z_val = lowpass_z.input(aclr_z_val);   // low pass filter z-axis

	angle_x = atan(-aclr_y_val / aclr_z_val);	  // rotation around x-axis (beta)
	angle_y = atan(aclr_x_val / aclr_z_val);		// rotation around y-axis (alpha)

	if (angle_x > PI / 2) {                     // limit angles between -PI/2 and PI/2
		angle_x = PI / 2;
	}
	if (angle_x < -PI / 2) {
		angle_x = -PI / 2;
	}
	if (angle_y > PI / 2) {
		angle_y = PI / 2;
	}
	if (angle_y < -PI / 2) {
		angle_y = -PI / 2;
	}

	if (angle_y != 0) {
		angle_u = -atan(tan(angle_x) / sin(angle_y));            // yaw-angle [y != 0]
	}
	if (angle_y == 0 && angle_x != 0) {
		angle_u = PI / 2 + atan(sin(angle_y) / tan(angle_x));    // yaw-angle [y == 0]
	}
	if (angle_y == 0 && angle_x == 0) {
		angle_u = 0;                                             // yaw-angle [x == 0 && y == 0]
	}

	mgni_u = hypot(cos(angle_x) * sin(angle_y), sin(angle_x)); // magnitude of yaw-angle

	if (angle_y < 0 && angle_x > 0) {                          // determine yaw-angle between 0 and 2PI
		angle_u = angle_u;
	}
	if (angle_y > 0 && angle_x > 0) {
		angle_u = PI + angle_u;
	}
	if (angle_y > 0 && angle_x < 0) {
		angle_u = PI + angle_u;
	}
	if (angle_y < 0 && angle_x < 0) {
		angle_u = 2 * PI + angle_u;
	}
	if (angle_u > 2 * PI) {
		angle_u = 2 * PI;
	}
}

void data() {
	stream = normdata(FCTR * angle_x, FCTR * angle_y, FCTR * angle_u, FCTR * mgni_u, stp_yaw, stp_cnt, stp_rpm);
	stream.toCharArray(stream_udp, stream.length() + 1);
	Serial.println(stream_udp);
}

void control() {
	time_a = time_b;
	time_b = millis();
	time_delta = time_b - time_a;

	time = millis();

	if (time % time_run < 50) {
		run_time = true;
	}
	else {
		run_time = false;
	}
	Serial.println(time);
	Serial.println(run_time);

	run_auto = digitalRead(TGL_PIN_AUTO);  // auto toggle switch
	run_demo = digitalRead(TGL_PIN_DEMO);  // demo toggle switch
}

void stepper() {
	stp_yaw = GER_COG - GER_COG / (2 * PI) * angle_u; // yaw-angle in steps

	if (stp_yaw > stp_cnt) {                          // calculate steps in both directions
		stp_yaw_left = stp_yaw - stp_cnt;
		stp_yaw_rght = stp_cnt + GER_COG - stp_yaw;
	}
	if (stp_yaw < stp_cnt) {
		stp_yaw_left = GER_COG - stp_cnt + stp_yaw;
		stp_yaw_rght = stp_cnt - stp_yaw;
	}

	if (run_demo && run_time) {
		STEPPER->setSpeed(stp_speed_demo);
		STEPPER->step(stp_steps_demo, FORWARD, MICROSTEP);
		stp_cnt += stp_steps_demo;
		STEPPER->release();
	}

	if (run_auto) { 
		if (stp_yaw_left < stp_yaw_rght && stp_yaw_left > stp_tol) { // define direction and speed of rotation according to least steps
			if (stp_yaw_left >= stp_speed_fast_lim) {
				stp_speed_fast_set = stp_speed(stp_yaw_left);
				STEPPER->setSpeed(stp_speed_fast_set);
				STEPPER->step(stp_steps_fast, FORWARD, MICROSTEP);
				stp_cnt += stp_steps_fast;
			}
			if (stp_yaw_left < stp_speed_fast_lim) {
				STEPPER->setSpeed(stp_speed_slow_set);
				STEPPER->step(stp_steps_slow, FORWARD, MICROSTEP);
				stp_cnt += stp_steps_slow;
			}
		}
		if (stp_yaw_left > stp_yaw_rght && stp_yaw_rght > stp_tol) {
			if (stp_yaw_rght >= stp_speed_fast_lim) {
				stp_speed_fast_set = stp_speed(stp_yaw_rght);
				STEPPER->setSpeed(stp_speed_fast_set);
				STEPPER->step(stp_steps_fast, BACKWARD, MICROSTEP);
				stp_cnt -= stp_steps_fast;
			}
			if (stp_yaw_rght < stp_speed_fast_lim) {
				STEPPER->setSpeed(stp_speed_slow_set);
				STEPPER->step(stp_steps_slow, BACKWARD, MICROSTEP);
				stp_cnt -= stp_steps_slow;
			}
		}
		else {
			STEPPER->release();
		}
	}

	if (!run_demo && !run_auto) {
		STEPPER->release();
	}

	if (stp_cnt >= GER_COG) { // rotation over zero
		stp_cnt = stp_cnt - GER_COG;
	}
	if (stp_cnt < 0) {
		stp_cnt = GER_COG + stp_cnt;
	}

	if (stp_cnt_safe != stp_cnt) { // stepper rpm
		stp_rpm = (float(stp_cnt_safe - stp_cnt) / float(time_delta)) * 60000 / STP_COG;
	}
	else {
		stp_rpm = 0;
	}
	stp_cnt_safe = stp_cnt;
}

void fan() {
	if (run_auto || run_demo == true) {
		FAN->run(FORWARD);
	}
	else {
		FAN->run(RELEASE);
	}
}

String normdata(float a, float b, float c, float d, int e, int f, float g) {
	String ret = String('!') + String(a) + String(' ') + String(b) + String(' ') + String(c) + String(' ') + String(d) +
		String(' ') + String(e) + String(' ') + String(f) + String(' ') + String(g) + String(' ') + String('#');
	return ret;
}

float stp_speed(int delta) {
	float ret = stp_speed_fast_incr * delta + stp_speed_fast_min;
	return ret;
}
