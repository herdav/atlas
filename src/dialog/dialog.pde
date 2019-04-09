// Dialog -------------------------------------
// 
// 
// 

// RSS Feed --------------------------------------------
RSS[] feed;
String[] feed_link, feed_inclusive, feed_exclusive;
StringList feed_senteces = new StringList();

// Database --------------------------------------------
JSONObject database_json;
JSONArray database_data;
StringList database_sentences = new StringList();
StringList databse_sentences_shuffle = new StringList();
IntList database_sequence = new IntList();
int database_sentences_count = 0;
int database_sequence_length = 120;
boolean database_shuffleAtStart = true;

// Display ---------------------------------------------
PFont display_font;
int display_textSize = 50;
int display_count = 0, display_count_max = 300;

void setup() {
  //fullScreen();
  size(3800, 500);
  frameRate(60);
  background(0);
  display_font = createFont("Consolas", display_textSize);
  textFont(display_font);
  xml();
  database();
  printDatabase("Database loaded..");
}

void draw() {
  background(0);
  noCursor();
  display();
}

void display() {
  display_count++;
  if (display_count == display_count_max) {
    display_count = 0;
    database_sentences_count++;
    if (database_sentences_count == database_sequence.size() || database_shuffleAtStart) {
      xml();
      database();
      database_shuffleAtStart = false;
      database_sentences_count = 0;
      database_sequence.shuffle();
      printDatabase("New sequence started..");
      databse_sentences_shuffle.clear();
      for (int i = 0; i < database_sentences.size(); i++) {
        databse_sentences_shuffle.append(database_sentences.get(database_sequence.get(i)));
      }
      saveList(databse_sentences_shuffle, "shuffle");
    }
  }
  textAlign(LEFT, TOP);
  text(database_sentences.get(database_sequence.get(database_sentences_count)), 50, 50);
}

void database() {
  database_json = loadJSONObject("\\data\\database_sentences.json");
  database_data = database_json.getJSONArray("sentences");
  database_sentences.clear();
  database_sequence.clear();

  for (int i = 0; i < database_data.size(); i++) {
    JSONObject sentence = database_data.getJSONObject(i);
    String text = sentence.getString("text");
    database_sentences.append(text);
    database_sequence.append(i);
  }

  int result_cnt = 0;
  for (int i = 0; i < feed.length; i++) {
    for (int j = 0; j < feed[i].result.size(); j++) {
      result_cnt++;
      database_sentences.append(feed[i].result.get(j));
      database_sequence.append(database_data.size() + result_cnt - 1);
      //println(database_data.size() + result_cnt, feed[i].result.get(j));
    }
  }
  saveList(database_sentences, "database");
}

void saveList(StringList list, String title) {
  String[] array = new String[list.size()];
  for (int i = 0; i < array.length; i++) {
    array[i] = i + ": " + list.get(i);
  }
  saveStrings("\\export\\" + title + ".txt", array);
}

void printDatabase(String titel) {
  println("\n>> " + titel);
  for (int i = 0; i < database_sequence.size(); i++) {
    println(i + ": " + database_sentences.get(database_sequence.get(i)));
  }
}

void xml() { // Import RSS-feeds.
  String[] feed_link = loadStrings("feed_links.txt");
  String[] feed_inclusive = loadStrings("feed_inclusive.txt");
  String[] feed_exclusive = loadStrings("feed_exclusive.txt");

  feed = new RSS[feed_link.length];
  feed_senteces.clear();

  int y = 0;
  for (int i = 0; i < feed.length; i++) {
    feed[i] = new RSS(feed_link[i]);
    feed[i].include(feed_inclusive);
    feed[i].exclude(feed_exclusive);
  }
}

class RSS {
  XML feed;
  String xml;
  String[] title, description, sentence;
  StringList result = new StringList();

  JSONObject expression_replace;
  JSONArray expression_replace_data;
  StringList expression_replace_org = new StringList();
  StringList expression_replace_new = new StringList();

  RSS(String xml) {
    this.xml = xml;
    feed = loadXML(xml);

    expression_replace_org.clear();
    expression_replace_new.clear();
    expression_replace = loadJSONObject("\\data\\feed_replace.json");
    expression_replace_data = expression_replace.getJSONArray("replace");
    for (int i = 0; i < expression_replace_data.size(); i++) {
      JSONObject data = expression_replace_data.getJSONObject(i);
      String data_org = data.getString("org");
      String data_new = data.getString("new");
      expression_replace_org.append(data_org);
      expression_replace_new.append(data_new);
    }
  }

  void include(String[] feed_inclusive) {
    XML[] titles = feed.getChildren("channel/item/title");
    XML[] descriptions = feed.getChildren("channel/item/description");

    sentence = new String[titles.length];
    result.clear();

    int pos_sentence = 0, pos_sentence_save = 0;

    for (int i = 0; i < titles.length; i++) {
      title = new String[titles.length];
      title[i] = titles[i].getContent().replaceAll("\n", "");

      description = new String[descriptions.length];
      description[i] = descriptions[i].getContent().replaceAll("\n", "");

      // Clean xml from html.
      int pos_start = 0, pos_end = 0;
      for (int n = 0; n < 3; n++) {
        for (int j = 0; j < description[i].length(); j++) {
          if (description[i].charAt(j) == '<') {
            pos_start = j;
            for (int k = j; k < description[i].length(); k++) {
              if (description[i].charAt(k) == '>') {
                pos_end = k;
                String clean = description[i].substring(pos_start, pos_end + 1);
                description[i] = description[i].replace(clean, "");
                break;
              }
            }
          }
        }
      }
      //println("\n>> Description " + i + ":\n   " + description[i]);

      // Replace specific expressions.
      for (int a = 0; a < expression_replace_org.size(); a++) {
        description[i] = description[i].replace(expression_replace_org.get(a), expression_replace_new.get(a));
      }

      // Select all sentences with the keywords.
      for (int j = 0; j < feed_inclusive.length; j++) {
        if (description[i].contains(feed_inclusive[j])) {
          int n = description[i].indexOf(feed_inclusive[j]);
          pos_start = n;
          pos_end = n;
          while (pos_start > 0) {
            pos_start--;
            if (description[i].charAt(pos_start) == '.' || description[i].charAt(pos_start) == '!' || description[i].charAt(pos_start) == '?') {
              break;
            }
          }
          while (pos_end < description[i].length() - 1) {
            pos_end++;
            if (description[i].charAt(pos_end) == '.' || description[i].charAt(pos_end) == '!' || description[i].charAt(pos_end) == '?') {
              break;
            }
          }

          // Shift whitespace at the beginning.
          if (pos_start != 0) {
            sentence[i] = description[i].substring(pos_start + 1, pos_end + 1);
          } else {
            sentence[i] = description[i].substring(pos_start, pos_end + 1);
          }
          while (sentence[i].charAt(0) == ' ') {
            pos_start++;
            sentence[i] = description[i].substring(pos_start, pos_end + 1);
          }

          // Change first character to capital letter.
          if (sentence[i].charAt(0) >= 96) {
            char[] temp = new char[sentence[i].length()];
            for (int t = 0; t < temp.length; t++) {
              temp[t] = sentence[i].charAt(t);
            }
            temp[0] -= 32;
            if (temp[0] < 65 || temp[0] > 122) {
              char[] temp_shift = new char[temp.length - 1];
              for (int u = 0; u < temp_shift.length; u++) {
                temp_shift[u] = temp[u + 1];
              }
              sentence[i] = new String(temp_shift);
            } else {
              sentence[i] = new String(temp);
            }
          }

          // Check for duplicate entries.
          pos_sentence = description[i].indexOf(sentence[i]);
          if (pos_sentence != pos_sentence_save && sentence[i].length() < database_sequence_length) {
            //result.append(i + ": " + title[i] + " ::::: " + sentence[i]);
            result.append(sentence[i]);
          }
          pos_sentence_save = pos_sentence;
        }
      }
    }
  }

  void exclude(String[] feed_exclusive) {
    // Check for exclusive expressions.
    for (int i = result.size() - 1; i >= 0; i--) {
      for (int m = 0; m < feed_exclusive.length; m++) {
        if (result.get(i).contains(feed_exclusive[m])) {
          //println(">> Removed: " + result.get(i));
          result.remove(i);
          break;
        }
      }
    }
  }
}
