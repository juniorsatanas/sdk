// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Helper for creating HTML visualization of the source map information
/// generated by a [SourceMapProcessor].

library sourcemap.html.helper;

import 'dart:convert';

import 'package:compiler/src/io/source_file.dart';
import 'package:compiler/src/io/source_information.dart';
import 'package:compiler/src/js/js.dart' as js;

import 'colors.dart';
import 'sourcemap_helper.dart';
import 'sourcemap_html_templates.dart';

/// Returns the [index]th color for visualization.
HSV toColor(int index) {
  int hueCount = 24;
  double h = 360.0 * (index % hueCount) / hueCount;
  double v = 1.0;
  double s = 0.5;
  return new HSV(h, s, v);
}

/// Return the CSS color value for the [index]th color.
String toColorCss(int index) {
  return toColor(index).toCss;
}

/// Return the CSS color value for the [index]th span.
String toPattern(int index) {
  /// Use gradient on spans to visually identify consecutive spans mapped to the
  /// same source location.
  HSV startColor = toColor(index);
  HSV endColor = new HSV(startColor.h, startColor.s + 0.4, startColor.v - 0.2);
  return 'linear-gradient(to right, ${startColor.toCss}, ${endColor.toCss})';
}

/// Return the html for the [index] line number.
String lineNumber(int index) {
  return '<span class="lineNumber">${index + 1} </span>';
}

/// Return the html escaped [text].
String escape(String text) {
  return const HtmlEscape().convert(text);
}

/// Information needed to generate HTML for a single [SourceMapInfo].
class SourceMapHtmlInfo {
  final SourceMapInfo sourceMapInfo;
  final CodeProcessor codeProcessor;
  final SourceLocationCollection sourceLocationCollection;

  SourceMapHtmlInfo(this.sourceMapInfo,
                    this.codeProcessor,
                    this.sourceLocationCollection);
}

/// A collection of source locations.
///
/// Used to index source locations for visualization and linking.
class SourceLocationCollection {
  List<SourceLocation> sourceLocations = [];
  Map<SourceLocation, int> sourceLocationIndexMap;

  SourceLocationCollection([SourceLocationCollection parent])
      : sourceLocationIndexMap =
            parent == null ? {} : parent.sourceLocationIndexMap;

  int registerSourceLocation(SourceLocation sourceLocation) {
    return sourceLocationIndexMap.putIfAbsent(sourceLocation, () {
      sourceLocations.add(sourceLocation);
      return sourceLocationIndexMap.length;
    });
  }

  int getIndex(SourceLocation sourceLocation) {
    return sourceLocationIndexMap[sourceLocation];
  }
}

/// Processor that computes the HTML representation of a block of JavaScript
/// code and collects the source locations mapped in the code.
class CodeProcessor {
  int lineIndex = 0;
  final String onclick;
  int currentJsSourceOffset = 0;
  final SourceLocationCollection collection;
  final Map<int, List<SourceLocation>> codeLocations = {};

  CodeProcessor(this.onclick, this.collection);

  void addSourceLocation(int targetOffset, SourceLocation sourceLocation) {
    codeLocations.putIfAbsent(targetOffset, () => []).add(sourceLocation);
    collection.registerSourceLocation(sourceLocation);
  }

  String convertToHtml(String text) {
    StringBuffer htmlBuffer = new StringBuffer();
    int offset = 0;
    int lineIndex = 0;
    bool pendingSourceLocationsEnd = false;
    htmlBuffer.write(lineNumber(lineIndex));
    SourceLocation currentLocation;

    void endCurrentLocation() {
      if (currentLocation != null) {
        htmlBuffer.write('</a>');
      }
      currentLocation = null;
    }

    void addSubstring(int until) {
      if (until <= offset) return;

      String substring = text.substring(offset, until);
      offset = until;
      bool first = true;
      for (String line in substring.split('\n')) {
        if (!first) {
          endCurrentLocation();
          htmlBuffer.write('\n');
          lineIndex++;
          htmlBuffer.write(lineNumber(lineIndex));
        }
        htmlBuffer.write(escape(line));
        first = false;
      }
    }

    void insertSourceLocations(List<SourceLocation> lastSourceLocations) {
      endCurrentLocation();

      String color;
      int index;
      String title;
      if (lastSourceLocations.length == 1) {
        SourceLocation sourceLocation = lastSourceLocations.single;
        if (sourceLocation != null) {
          index = collection.getIndex(sourceLocation);
          color = "background:${toPattern(index)};";
          title = sourceLocation.shortText;
          currentLocation = sourceLocation;
        }
      } else {

        index = collection.getIndex(lastSourceLocations.first);
        StringBuffer sb = new StringBuffer();
        double delta = 100.0 / (lastSourceLocations.length);
        double position = 0.0;

        void addColor(String color) {
          sb.write(', ${color} ${position.toInt()}%');
          position += delta;
          sb.write(', ${color} ${position.toInt()}%');
        }

        for (SourceLocation sourceLocation in lastSourceLocations) {
          if (sourceLocation == null) continue;
          int colorIndex = collection.getIndex(sourceLocation);
          addColor('${toColorCss(colorIndex)}');
          currentLocation = sourceLocation;
        }
        color = 'background: linear-gradient(to right${sb}); '
                'background-size: 10px 10px;';
        title = lastSourceLocations.map((l) => l.shortText).join(',');
      }
      if (index != null) {
        Set<int> indices =
            lastSourceLocations.map((l) => collection.getIndex(l)).toSet();
        String onmouseover = indices.map((i) => '\'$i\'').join(',');
        htmlBuffer.write(
            '<a name="js$index" href="#${index}" style="$color" title="$title" '
            'onclick="${onclick}" onmouseover="highlight([${onmouseover}]);"'
            'onmouseout="highlight([]);">');
        pendingSourceLocationsEnd = true;
      }
      if (lastSourceLocations.last == null) {
        endCurrentLocation();
      }
    }

    for (int targetOffset in codeLocations.keys.toList()..sort()) {
      List<SourceLocation> sourceLocations = codeLocations[targetOffset];
      addSubstring(targetOffset);
      insertSourceLocations(sourceLocations);
    }

    addSubstring(text.length);
    endCurrentLocation();
    return htmlBuffer.toString();
  }
}

/// Computes the HTML representation for a collection of JavaScript code blocks.
String computeJsHtml(Iterable<SourceMapHtmlInfo> infoList) {

  StringBuffer jsCodeBuffer = new StringBuffer();
  for (SourceMapHtmlInfo info in infoList) {
    String name = info.sourceMapInfo.name;
    String html = info.codeProcessor.convertToHtml(info.sourceMapInfo.code);
    String onclick = 'show(\'$name\');';
    jsCodeBuffer.write(
        '<h3 onclick="$onclick">JS code for: ${escape(name)}</h3>\n');
    jsCodeBuffer.write('''
<pre>
$html
</pre>
''');
  }
  return jsCodeBuffer.toString();
}

/// Computes the HTML representation of the source mapping information for a
/// collection of JavaScript code blocks.
String computeJsTraceHtml(Iterable<SourceMapHtmlInfo> infoList) {
  StringBuffer jsTraceBuffer = new StringBuffer();
  for (SourceMapHtmlInfo info in infoList) {
    String name = info.sourceMapInfo.name;
    String jsTrace = computeJsTraceHtmlPart(
        info.sourceMapInfo.codePoints, info.sourceLocationCollection);
    jsTraceBuffer.write('''
<div name="$name" class="js-trace-buffer" style="display:none;">
<h3>Trace for: ${escape(name)}</h3>
$jsTrace
</div>
''');
  }
  return jsTraceBuffer.toString();
}

/// Computes the HTML information for the [info].
SourceMapHtmlInfo createHtmlInfo(SourceLocationCollection collection,
                                 SourceMapInfo info) {
  js.Node node = info.node;
  String code = info.code;
  String name = info.name;
  String onclick = 'show(\'$name\');';
  SourceLocationCollection subcollection =
      new SourceLocationCollection(collection);
  CodeProcessor codeProcessor = new CodeProcessor(onclick, subcollection);
  for (js.Node node in info.nodeMap.nodes) {
    info.nodeMap[node].forEach(
        (int targetOffset, List<SourceLocation> sourceLocations) {
      for (SourceLocation sourceLocation in sourceLocations) {
        codeProcessor.addSourceLocation(targetOffset, sourceLocation);
      }
    });
  }
  return new SourceMapHtmlInfo(info, codeProcessor, subcollection);
}

/// Outputs a HTML file in [jsMapHtmlUri] containing an interactive
/// visualization of the source mapping information in [infoList] computed
/// with the [sourceMapProcessor].
void createTraceSourceMapHtml(Uri jsMapHtmlUri,
                              SourceMapProcessor sourceMapProcessor,
                              Iterable<SourceMapInfo> infoList) {
  SourceFileManager sourceFileManager = sourceMapProcessor.sourceFileManager;
  SourceLocationCollection collection = new SourceLocationCollection();
  List<SourceMapHtmlInfo> htmlInfoList = <SourceMapHtmlInfo>[];
  for (SourceMapInfo info in infoList) {
    htmlInfoList.add(createHtmlInfo(collection, info));
  }

  String jsCode = computeJsHtml(htmlInfoList);
  String dartCode = computeDartHtml(sourceFileManager, htmlInfoList);

  String jsTraceHtml = computeJsTraceHtml(htmlInfoList);
  outputJsDartTrace(jsMapHtmlUri, jsCode, dartCode, jsTraceHtml);
  print('Trace source map html generated: $jsMapHtmlUri');
}

/// Computes the HTML representation for the Dart code snippets referenced in
/// [infoList].
String computeDartHtml(
    SourceFileManager sourceFileManager,
    Iterable<SourceMapHtmlInfo> infoList) {

  StringBuffer dartCodeBuffer = new StringBuffer();
  for (SourceMapHtmlInfo info in infoList) {
    dartCodeBuffer.write(computeDartHtmlPart(info.sourceMapInfo.name,
         sourceFileManager, info.sourceLocationCollection));
  }
  return dartCodeBuffer.toString();

}

/// Computes the HTML representation for the Dart code snippets in [collection].
String computeDartHtmlPart(String name,
                           SourceFileManager sourceFileManager,
                           SourceLocationCollection collection,
                           {bool showAsBlock: false}) {
  const int windowSize = 3;
  StringBuffer dartCodeBuffer = new StringBuffer();
  Map<Uri, Map<int, List<SourceLocation>>> sourceLocationMap = {};
  collection.sourceLocations.forEach((SourceLocation sourceLocation) {
    Map<int, List<SourceLocation>> uriMap =
        sourceLocationMap.putIfAbsent(sourceLocation.sourceUri, () => {});
    List<SourceLocation> lineList =
        uriMap.putIfAbsent(sourceLocation.line, () => []);
    lineList.add(sourceLocation);
  });
  sourceLocationMap.forEach((Uri uri, Map<int, List<SourceLocation>> uriMap) {
    SourceFile sourceFile = sourceFileManager.getSourceFile(uri);
    StringBuffer codeBuffer = new StringBuffer();

    int firstLineIndex;
    int lastLineIndex;

    void flush() {
      if (firstLineIndex != null && lastLineIndex != null) {
        dartCodeBuffer.write(
            '<h4>${uri.pathSegments.last}, '
            '${firstLineIndex - windowSize + 1}-'
            '${lastLineIndex + windowSize + 1}'
            '</h4>\n');
        dartCodeBuffer.write('<pre>\n');
        for (int line = firstLineIndex - windowSize;
             line < firstLineIndex;
             line++) {
          if (line >= 0) {
            dartCodeBuffer.write(lineNumber(line));
            dartCodeBuffer.write(sourceFile.getLineText(line));
          }
        }
        dartCodeBuffer.write(codeBuffer);
        for (int line = lastLineIndex + 1;
             line <= lastLineIndex + windowSize;
             line++) {
          if (line < sourceFile.lines) {
            dartCodeBuffer.write(lineNumber(line));
            dartCodeBuffer.write(sourceFile.getLineText(line));
          }
        }
        dartCodeBuffer.write('</pre>\n');
        firstLineIndex = null;
        lastLineIndex = null;
      }
      codeBuffer.clear();
    }

    List<int> lineIndices = uriMap.keys.toList()..sort();
    lineIndices.forEach((int lineIndex) {
      List<SourceLocation> locations = uriMap[lineIndex];
      if (lastLineIndex != null &&
          lastLineIndex + windowSize * 4 < lineIndex) {
        flush();
      }
      if (firstLineIndex == null) {
        firstLineIndex = lineIndex;
      } else {
        for (int line = lastLineIndex + 1; line < lineIndex; line++) {
          codeBuffer.write(lineNumber(line));
          codeBuffer.write(sourceFile.getLineText(line));
        }
      }
      String line = sourceFile.getLineText(lineIndex);
      locations.sort((a, b) => a.offset.compareTo(b.offset));
      for (int i = 0; i < locations.length; i++) {
        SourceLocation sourceLocation = locations[i];
        int index = collection.getIndex(sourceLocation);
        int start = sourceLocation.column;
        int end = line.length;
        if (i + 1 < locations.length) {
          end = locations[i + 1].column;
        }
        if (i == 0) {
          codeBuffer.write(lineNumber(lineIndex));
          codeBuffer.write(line.substring(0, start));
        }
        codeBuffer.write(
            '<a name="${index}" style="background:${toPattern(index)};" '
            'title="[${lineIndex + 1},${start + 1}]" '
            'onmouseover="highlight(\'$index\');" '
            'onmouseout="highlight();">');
        codeBuffer.write(line.substring(start, end));
        codeBuffer.write('</a>');
      }
      lastLineIndex = lineIndex;
    });

    flush();
  });
  String display = showAsBlock ? 'block' : 'none';
  return '''
<div name="$name" class="dart-buffer" style="display:$display;">
<h3>Dart code for: ${escape(name)}</h3>
${dartCodeBuffer}
</div>''';
}

/// Computes a HTML visualization of the [codePoints].
String computeJsTraceHtmlPart(List<CodePoint> codePoints,
                              SourceLocationCollection collection) {
  StringBuffer buffer = new StringBuffer();
  buffer.write('<table style="width:100%;">');
  buffer.write(
      '<tr><th>Node kind</th><th>JS code @ offset</th>'
      '<th>Dart code @ mapped location</th><th>file:position:name</th></tr>');
  codePoints.forEach((CodePoint codePoint) {
    String jsCode = codePoint.jsCode;
    if (codePoint.sourceLocation != null) {
      int index = collection.getIndex(codePoint.sourceLocation);
      if (index != null) {
        String style = '';
        if (!codePoint.isMissing) {
          style = 'style="background:${toColorCss(index)};" ';
        }
        buffer.write('<tr $style'
                     'name="trace$index" '
                     'onmouseover="highlight([${index}]);"'
                     'onmouseout="highlight([]);">');
      } else {
        buffer.write('<tr>');
        print('${codePoint.sourceLocation} not found in ');
        collection.sourceLocationIndexMap.keys
            .where((l) => l.sourceUri == codePoint.sourceLocation.sourceUri)
            .forEach((l) => print(' $l'));
      }
    } else {
      buffer.write('<tr>');
    }
    buffer.write('<td>${codePoint.kind}</td>');
    buffer.write('<td class="code">${jsCode}</td>');
    if (codePoint.sourceLocation == null) {
      //buffer.write('<td></td>');
    } else {
      buffer.write('<td class="code">${codePoint.dartCode}</td>');
      buffer.write('<td>${escape(codePoint.sourceLocation.shortText)}</td>');
    }
    buffer.write('</tr>');
  });
  buffer.write('</table>');

  return buffer.toString();
}
