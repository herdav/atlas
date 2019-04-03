RSS[] feed;
String[] link, search, excluse;
StringList feed_senteces = new StringList();
int textSize = 40;

void setup() {
  //fullScreen();
  size(1920, 1080);
  background(0);
  xml();
}

void draw() {
  //background(0);
  //xml();
}

void xml() { // Imports rss-feeds and display specific data.
  String[] link = loadStrings("links.txt");
  String[] search = loadStrings("search.txt");
  String[] excluse = loadStrings("excluse.txt");

  feed = new RSS[link.length];
  feed_senteces.clear();

  int y = 0;
  for (int i = 0; i < feed.length; i++) {
    feed[i] = new RSS(link[i]);
    feed[i].loadFeed(search, excluse);
    if (i > 0) {
      y += feed[i - 1].result.size();
      feed[i].display(y);
    } else {
      feed[i].display(0);
    }
  }
  println(feed_senteces);
}

class RSS {
  XML feed;
  String xml;
  String[] title, description, sentence;
  StringList result = new StringList();

  RSS(String xml) {
    this.xml = xml;
    feed = loadXML(xml);
  }

  void loadFeed(String[] search, String[] excluse) {
    XML[] titles = feed.getChildren("channel/item/title");
    XML[] descriptions = feed.getChildren("channel/item/description");

    sentence = new String[titles.length];
    result.clear();

    int pos_sentence = 0, pos_sentence_save = 0;

    for (int i = 0; i < titles.length; i++) {
      title = new String[titles.length];
      title[i] = titles[i].getContent().replaceAll(("\n"), "");
      description = new String[descriptions.length];
      description[i] = descriptions[i].getContent().replaceAll("\n", "");

      // Clean xml from html
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
                println(clean);
                break;
              }
            }
          }
        }
      }

      boolean excl = false;
      for (int m = 0; m < excluse.length; m++) {
        if (description[i].contains(excluse[m])) {
          excl = true;
        }
      }

      if (!excl) {
        for (int j = 0; j < search.length; j++) {
          if (description[i].contains(search[j])) {
            int n = description[i].indexOf(search[j]);
            pos_start = n;
            pos_end = n;
            while (true && pos_start > 0) {
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

            if (pos_start != 0) {
              sentence[i] = description[i].substring(pos_start + 1, pos_end + 1);
            } else {
              sentence[i] = description[i].substring(pos_start, pos_end + 1);
            }
            while (sentence[i].charAt(0) == ' ') {
              pos_start++;
              sentence[i] = description[i].substring(pos_start, pos_end + 1);
            }

            pos_sentence = description[i].indexOf(sentence[i]);
            if (pos_sentence != pos_sentence_save && sentence[i].length() < 100) {
              //result.append(i + ": " + title[i] + " ::::: " + sentence[i]);
              result.append(sentence[i]);
              feed_senteces.append(sentence[i]);
            }
            pos_sentence_save = pos_sentence;
          }
        }
      }
    }
  }

  void display(int y) {
    int count = 0;
    for (int i = 0; i < result.size(); i++) {
      if (result.get(i) != null) {
        count++;
        if (true) {
          textAlign(LEFT);
          textSize(textSize);
          text(result.get(i), textSize, textSize * (count + y) * 1.5);
        }
      }
    }
  }
}
