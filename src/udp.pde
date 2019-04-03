import hypermedia.net.*;

// STREAM ---------------------------------------------------------------------------------------------------------
UDP udp;
boolean connected = false;

String stream_data, stream_data_eff;
float[] stream_data_val;
float stream_data_angle_x, stream_data_angle_y, stream_data_angle_u, 
  stream_data_magni_u, stream_data_stp_yaw, stream_data_stp_cnt, 
  stream_data_poti, stream_data_rpm, stream_data_angle_stp, 
  stream_data_angle_rot;
int stream_data_fctr = 1;

// POINTER --------------------------------------------------------------------------------------------------------
Pointer pointer_yaw, pointer_x_axis, pointer_y_axis, pointer_stp;
Pointer pointer_targets;
boolean pointer_control = false;
int pointer_d = 320;

void setup() {
  size(2000, 1000);
  //fullScreen();
  udp = new UDP(this, 6000);   // create a new datagram connection on port 6000
  //udp.log(true);             // printout the connection activity
  udp.listen(true);            // and wait for incoming message

  pointer_x_axis = new Pointer(width / 2 - 2*pointer_d, height / 2, pointer_d);
  pointer_y_axis = new Pointer(width / 2, height / 2, pointer_d);
  pointer_yaw = new Pointer(width / 2 + 2*pointer_d, height / 2, pointer_d);
  pointer_stp = new Pointer(width / 2 + 2*pointer_d, height / 2, pointer_d);
}

void draw() {
  background(150);
  pointer();
  if (!connected) {
    String ip = "192.168.1.33";  // the remote IP address
    int port = 2390;             // the destination port
    
    String massage = "..waiting for data";
    udp.send(massage, ip, port);
    println(massage);
    delay(500);
  }
}

void pointer() {
  pointer_x_axis.calculation(stream_data_angle_x, 1);
  pointer_x_axis.needle(true);
  pointer_x_axis.graph(false, 30);
  pointer_x_axis.magnitude();
  pointer_x_axis.path(true, color(0, 255, 0, 200));
  pointer_x_axis.title("X-AXIS");

  pointer_y_axis.calculation(stream_data_angle_y, 1);
  pointer_y_axis.needle(true);
  pointer_y_axis.graph(false, 30);
  pointer_y_axis.magnitude();
  pointer_y_axis.path(true, color(0, 255, 0, 200));
  pointer_y_axis.title("Y-AXIS");

  pointer_stp.calculation(stream_data_angle_stp, sqrt(sq(stream_data_rpm)) / 35);
  pointer_stp.needle(false);
  pointer_stp.magnitude();
  pointer_stp.path(true, color(255, 0, 255, 200));

  pointer_yaw.calculation(stream_data_angle_rot, stream_data_magni_u*5);
  pointer_yaw.needle(true);
  pointer_yaw.graph(false, 5);
  pointer_yaw.magnitude();
  pointer_yaw.path(true, color(0, 255, 0, 200));
  pointer_yaw.title("YAW-ANGLE");
}

class Pointer {
  PVector orgin = new PVector();
  PVector needle = new PVector();
  PVector magnitude = new PVector();
  PVector[] path_store = new PVector[100];
  float a, d, r;
  float[] graph_store;
  int graph_count = 0, path_count = 0;
  color gray = color(50), brgt = color(255);

  Pointer(float x, float y, float d) {
    orgin.x = x;
    orgin.y = y;
    this.d = d;
    r = d / 2;

    graph_store = new float[int(d)];
    for (int i = 0; i < path_store.length; i++) path_store[i] = new PVector();
  }

  void calculation(float angle, float m) {
    a = angle;
    needle.x = orgin.x + r * cos(a);
    needle.y = orgin.y + r * sin(a);
    magnitude.x = orgin.x + r * cos(a) * m;
    magnitude.y = orgin.y + r * sin(a) * m;
  }

  void needle(boolean b) {
    noFill();
    stroke(gray);
    if (b) ellipse(orgin.x, orgin.y, d, d);
    line(orgin.x, orgin.y - r, orgin.x, orgin.y + r);
    line(orgin.x - r, orgin.y, orgin.x + r, orgin.y);
    stroke(brgt);
    line(orgin.x, orgin.y, needle.x, needle.y);

    for (int i = 0; i <= 360; i += 30) {
      float s = i * PI / 180;
      if (i % 90 > 0) {
        stroke(gray);
        line(orgin.x + r * cos(s), orgin.y + r * sin(s), orgin.x + (r - 10) * cos(s), 
          orgin.y + (r - 10) * sin(s));
      }
    }
  }

  void magnitude() {
    noFill();
    stroke(brgt);
    ellipse(magnitude.x, magnitude.y, 8, 8);
  }

  void path(boolean set, color c) {
    if (set) {
      path_count++;
      if (path_count == path_store.length - 1) path_count = 0;
      path_store[path_count].x = magnitude.x;
      path_store[path_count].y = magnitude.y;
      noStroke();
      fill(c);
      for (int i = 0; i < path_store.length; i++) ellipse(path_store[i].x, path_store[i].y, 2, 2);
    }
  }

  void graph(boolean set, int f) {
    if (set) {
      graph_count++;
      if (graph_count == d - 1) graph_count = 0;
      graph_store[graph_count] = f * a;
      stroke(gray);
      for (int i = 0; i < graph_store.length; i++) line(orgin.x - r + i, orgin.y + d / 1.5, 
        orgin.x - r + i, orgin.y + d / 1.5 - graph_store[i]);
    }
  }

  void title(String t) {
    textSize(20);
    fill(255);
    textAlign(CENTER, CENTER);
    text(t + ": " + float(int(10 * a * 180 / PI)) / 10 + '°', orgin.x, orgin.y + r + r / 5);
  }
}

void keyPressed() {
  String ip = "192.168.1.33";  // the remote IP address
  int port = 2390;             // the destination port
  udp.send(" ", ip, port);     // the message to send
}

void receive(byte[] data) {    //default handler
  stream_data = "";
  for (int i=0; i < data.length; i++) {
    stream_data += char(data[i]);
  }
  //println(stream_data);

  if (stream_data.charAt(0) == '!') {
    connected = true;

    stream_data_eff = stream_data.substring(stream_data.indexOf('!') + 1, stream_data.indexOf('#'));
    stream_data_val = float(split(stream_data_eff, ' '));
    stream_data_angle_x = stream_data_val[0] / stream_data_fctr;
    stream_data_angle_y = stream_data_val[1] / stream_data_fctr;
    stream_data_angle_u = stream_data_val[2] / stream_data_fctr;
    stream_data_magni_u = stream_data_val[3] / stream_data_fctr;
    stream_data_stp_yaw = stream_data_val[4];
    stream_data_stp_cnt = stream_data_val[5];
    stream_data_rpm = stream_data_val[6];

    if (stream_data_angle_u >= 0 && stream_data_angle_u < PI / 2) {
      stream_data_angle_rot = stream_data_angle_u;
    }
    if (stream_data_angle_u >= PI / 2 && stream_data_angle_u < PI) {
      stream_data_angle_rot = PI - stream_data_angle_u;
    }
    if (stream_data_angle_u >= PI && stream_data_angle_u < 2 / 3 * PI) {
      stream_data_angle_rot = stream_data_angle_u - PI;
    }
    if (stream_data_angle_u >= 2 / 3 * PI && stream_data_angle_u < 2 * PI) {
      stream_data_angle_rot = 2 * PI - stream_data_angle_u;
    }

    stream_data_angle_stp = 2 * PI / 600 * stream_data_stp_cnt;


    println("x:" + int(stream_data_angle_x * 180 / PI), "y:" + int(stream_data_angle_y * 180 / PI), 
      "u:" + int(stream_data_angle_u * 180 / PI), "m:" + int(100 * stream_data_magni_u), 
      "stp:" + int(stream_data_stp_yaw), "cnt:" + int(stream_data_stp_cnt), 
      "speed:" + int(stream_data_rpm));
  }
}
