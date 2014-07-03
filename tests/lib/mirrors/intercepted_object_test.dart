// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Ensure that objects handled specially by dart2js can be reflected on.

library test.intercepted_object_test;

import 'dart:mirrors';

import 'stringify.dart' show stringify, expect;

import 'intercepted_class_test.dart' show checkClassMirrorMethods;

checkImplements(object, String name) {
  ClassMirror cls = reflect(object).type;
  checkClassMirrorMethods(cls);

  List<ClassMirror> superinterfaces = cls.superinterfaces;
  String symName = 's($name)';
  for (ClassMirror superinterface in superinterfaces) {
    print(superinterface.simpleName);
    if (symName == stringify(superinterface.simpleName)) {
      checkClassMirrorMethods(superinterface);
      return;
    }
  }

  // TODO(floitsch): use correct fail
  expect(name, "super interface not found");
}

main() {
  checkImplements('', 'String');
  checkImplements(1, 'int');
  checkImplements(1.5, 'double');
  checkImplements(true, 'bool');
  checkImplements(false, 'bool');
  checkImplements([], 'List');
}