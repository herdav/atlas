/*  ATLAS/DIALOG --------------------------------------------------------------------------------------------------
    Created 2019 by David Herren.                                                                                 /
    https://davidherren.ch                                                                                        /
    https://github.com/herdav/atlas                                                                               /
    Licensed under the MIT License.                                                                               /
    ---------------------------------------------------------------------------------------------------------------
*/

// RSS FEED -------------------------------------------------------------------------------------------------------
RSS[] feed;
String[] feed_link, feed_inclusive, feed_exclusive;
StringList feed_senteces = new StringList();

// DATABASE -------------------------------------------------------------------------------------------------------
JSONObject database_json;
JSONArray database_data;
StringList database_sentences = new StringList();
StringList database_keywords = new StringList();
StringList database_sentences_shuffle = new StringList();
IntList database_sequence = new IntList();
int database_sentences_count = 0;
int database_sequence_length_max = 70;
int database_sequence_length_min = 10;
int database_sequence_words_min = 3;
boolean database_shuffleAtStart = true;

// DISPLAY --------------------------------------------------------------------------------------------------------
PFont display_font;
int display_textSize = 80;
int display_offset_x = 50;
int display_offset_y = 800;
int display_count = 0, display_count_max = 600;

void setup() {
  fullScreen();
  //size(3800, 500);
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
  if (keyCode == UP) { // 
    text(database_sentences.get(7), display_offset_x, display_offset_y);
  } else {
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
        database_sentences_shuffle.clear();
        for (int i = 0; i < database_sentences.size(); i++) {
          database_sentences_shuffle.append(database_sentences.get(database_sequence.get(i)));
        }
        saveList(database_sentences_shuffle, "shuffle");
      }
    }
    textAlign(LEFT, TOP);
    text(database_sentences.get(database_sequence.get(database_sentences_count)), display_offset_x, display_offset_y);
  }
}

void xml() {
  // Imports RSS-feeds.
  String[] feed_link = loadStrings("feed_links.txt");
  String[] feed_inclusive = loadStrings("feed_inclusive.txt");
  String[] feed_exclusive = loadStrings("feed_exclusive.txt");

  StringList keywords = new StringList();
  keywords.clear();

  for (int i = 0; i < feed_inclusive.length; i++) {
    keywords.append(feed_inclusive[i]);
  }
  for (int i = 0; i < database_keywords.size(); i++) {
    keywords.append(database_keywords.get(i));
  }
  removeDublicates(keywords);
  println("\n>> Keywords loaded..");
  for (String keyword: keywords) {
    println(keyword);
  }

  feed_inclusive = new String[keywords.size()];
  for (int i = 0; i < feed_inclusive.length; i++) {
    feed_inclusive[i] = keywords.get(i);
  }

  feed = new RSS[feed_link.length];
  feed_senteces.clear();

  for (int i = 0; i < feed.length; i++) {
    feed[i] = new RSS(feed_link[i]);
    feed[i].load();
    feed[i].include(feed_inclusive);
    feed[i].exclude(feed_exclusive);
    feed[i].words();
  }
}

void database() {
  database_json = loadJSONObject("\\data\\database_sentences.json");
  database_data = database_json.getJSONArray("sentences");
  database_sentences.clear();
  database_sequence.clear();
  database_keywords.clear();

  for (int i = 0; i < database_data.size(); i++) {
    JSONObject sentence = database_data.getJSONObject(i);
    String text = sentence.getString("text");
    database_sentences.append(text);
    database_sequence.append(i);

    // Loads keywords from database.
    String keywords = sentence.getString("keywords");
    String[] keyword = split(keywords, ", ");
    for (int j = 0; j < keyword.length; j++) {
      if (!keyword[j].equals("n/A")) {
        database_keywords.append(keyword[j]);
      }
    }
  }
  removeDublicates(database_keywords);

  int result_cnt = 0;
  for (int i = 0; i < feed.length; i++) {
    for (int j = 0; j < feed[i].result.size(); j++) {
      result_cnt++;
      database_sentences.append(feed[i].result.get(j));
      database_sequence.append(database_data.size() + result_cnt - 1);
    }
  }
  saveList(database_sentences, "database");
}

void saveList(StringList list, String title) {
  String[] array = new String[list.size()];
  for (int i = 0; i < array.length; i++) {
    array[i] = list.get(i);
  }
  saveStrings("\\export\\" + title + ".txt", array);
}

void printDatabase(String titel) {
  println("\n>> " + titel);
  for (int i = 0; i < database_sequence.size(); i++) {
    println(i + ": " + database_sentences.get(database_sequence.get(i)));
  }
}

StringList removeDublicates(StringList list) {
  for (int i = 0; i < list.size(); i++) {
    for (int j = i + 1; j < list.size(); j++) {
      if (list.get(i).equals(list.get(j))) {
        list.remove(j);
        j--;
      }
    }
  }
  return list;
}

class RSS {
  XML feed;
  XML[] titles, descriptions;

  String xml;
  String[] title, description, sentence;
  StringList description_sentence = new StringList();
  StringList result = new StringList();

  JSONObject expression_replace;
  JSONArray expression_replace_data;
  StringList expression_replace_org = new StringList();
  StringList expression_replace_new = new StringList();

  int words = 0;

  RSS(String xml) {
    this.xml = xml;
    feed = loadXML(xml);
    titles = feed.getChildren("channel/item/title");
    descriptions = feed.getChildren("channel/item/description");

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

  void load() {
    sentence = new String[titles.length];
    int pos_start, pos_end;
    description_sentence.clear();
    result.clear();

    for (int i = 0; i < titles.length; i++) {
      title = new String[titles.length];
      title[i] = titles[i].getContent().replaceAll("\n", "");

      description = new String[descriptions.length];
      description[i] = descriptions[i].getContent().replaceAll("\n", "");

      // Cleans xml from html.
      pos_start = 0;
      pos_end = 0;
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
      // Replaces specific expressions.
      for (int a = 0; a < expression_replace_org.size(); a++) {
        description[i] = description[i].replace(expression_replace_org.get(a), expression_replace_new.get(a));
      }
      // Splits description in sentences.
      pos_start = 0;
      pos_end = 0;
      while (pos_end < description[i].length() - 1) {
        pos_end++;
        if (description[i].charAt(pos_end) == '.' || description[i].charAt(pos_end) == '!' || description[i].charAt(pos_end) == '?') {
          description_sentence.append(description[i].substring(pos_start, pos_end + 1));
          pos_start = pos_end + 1;
        }
      }
    }

    // Formats sentences.
    for (int i = 0; i < description_sentence.size(); i++) {
      // Shifts whitespace at the beginning.
      pos_start = 0;
      while (description_sentence.get(i).charAt(pos_start) == ' ') {
        pos_start++;
      }
      description_sentence.set(i, description_sentence.get(i).substring(pos_start, description_sentence.get(i).length()));

      // Changes first character to capital letter.
      if (description_sentence.get(i).charAt(0) > 96 && description_sentence.get(i).charAt(0) < 123) {
        char[] temp = new char[description_sentence.get(i).length()];
        for (int t = 0; t < temp.length; t++) {
          temp[t] = description_sentence.get(i).charAt(t);
        }
        temp[0] -= 32;
        if (temp[0] < 65 || temp[0] > 122) {
          char[] temp_shift = new char[temp.length - 1];
          for (int u = 0; u < temp_shift.length; u++) {
            temp_shift[u] = temp[u + 1];
          }
          description_sentence.set(i, new String(temp_shift));
        } else {
          description_sentence.set(i, new String(temp));
        }
      }
    }
  }

  void include(String[] feed_inclusive) {
    // Sets results.
    for (String sentence: description_sentence) {
      for (int i = 0; i < feed_inclusive.length; i++) {
        if (sentence.contains(feed_inclusive[i]) && sentence.length() < database_sequence_length_max && sentence.length() > database_sequence_length_min) {
          if (sentence.charAt(0) >= 65 && sentence.charAt(0) <= 90) {
            // Include only correct formated sentences.
            result.append(sentence);
          }
        }
      }
    }
    removeDublicates(result);
  }

  void exclude(String[] feed_exclusive) {
    // Checks for exclusive expressions.
    for (int i = result.size() - 1; i >= 0; i--) {
      for (int j = 0; j < feed_exclusive.length; j++) {
        if (result.get(i).contains(feed_exclusive[j])) {
          result.remove(i);
          break;
        }
      }
    }
    // Checks for upper characters.
    for (int i = result.size() - 1; i >= 0; i--) {
      for (int j = 1; j < result.get(i).length() - 1; j++) {
        if (result.get(i).charAt(j) < 97 && result.get(i).charAt(j) > 32 && result.get(i).charAt(j) != 111) {
          result.remove(i);
          break;
        }
      }
    }
  }

  void words() {
    // Counts words and removes short sentences.
    String[] results = result.array();
    for (int i = results.length - 1; i >= 0; i--) {
      String[] words = split(results[i], ' ');
      if (words.length < database_sequence_words_min) {
        result.remove(i);
      }
    }
  }
}
