JSONObject json;
JSONArray data;
String[] sentences;
int count = 0, count_max = 200;
int count_sentence = 0;
IntList sequence;
PFont font;

void setup() {
  //size(1920, 1080);
  fullScreen();
  frameRate(60);
  //font = createFont("Consolas", 40);
  font = createFont("Consolas", 80);
  textFont(font);

  json = loadJSONObject("\\data\\sentences.json");
  data = json.getJSONArray("sentences");
  sentences = new String[data.size()];
  sequence = new IntList();

  for (int i = 0; i < data.size(); i++) {
    JSONObject sentence = data.getJSONObject(i);
    String text = sentence.getString("text");
    sentences[i] = text;
    sequence.append(i);
    println(i + ", " + text);
  }
}

void draw() {
  background(0);
  noCursor();
  count++;

  if (count == count_max) {
    count = 0;
    count_sentence++;
    if (count_sentence == data.size()) {
      count_sentence = 0;
      sequence.shuffle();
      println("\n>> New sequence started.");
      for (int i = 0; i < data.size(); i++) {
        println(i + ", " + sentences[sequence.get(i)]);
      }
    }
  }

  textAlign(LEFT, TOP);
  text(sentences[sequence.get(count_sentence)], 50, 50);
}