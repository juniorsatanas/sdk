// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library analyzer.src.dart.element.member;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:analyzer/src/dart/element/type.dart';
import 'package:analyzer/src/generated/constant.dart'
    show DartObject, EvaluationResultImpl;
import 'package:analyzer/src/generated/engine.dart'
    show AnalysisContext, AnalysisEngine;
import 'package:analyzer/src/generated/java_core.dart';
import 'package:analyzer/src/generated/java_engine.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/utilities_dart.dart';

/**
 * A constructor element defined in a parameterized type where the values of the
 * type parameters are known.
 */
class ConstructorMember extends ExecutableMember implements ConstructorElement {
  /**
   * Initialize a newly created element to represent a constructor, based on the
   * [baseElement], defined by the [definingType]. If [type] is passed, it
   * represents the full type of the member, and will take precedence over
   * the [definingType].
   */
  ConstructorMember(ConstructorElement baseElement, InterfaceType definingType,
      [FunctionType type])
      : super(baseElement, definingType, type);

  @override
  ConstructorElement get baseElement => super.baseElement as ConstructorElement;

  @override
  InterfaceType get definingType => super.definingType as InterfaceType;

  @override
  ClassElement get enclosingElement => baseElement.enclosingElement;

  @override
  bool get isConst => baseElement.isConst;

  @override
  bool get isDefaultConstructor => baseElement.isDefaultConstructor;

  @override
  bool get isFactory => baseElement.isFactory;

  @override
  int get nameEnd => baseElement.nameEnd;

  @override
  int get periodOffset => baseElement.periodOffset;

  @override
  ConstructorElement get redirectedConstructor =>
      from(baseElement.redirectedConstructor, definingType);

  @override
  accept(ElementVisitor visitor) => visitor.visitConstructorElement(this);

  @override
  ConstructorDeclaration computeNode() => baseElement.computeNode();

  @override
  String toString() {
    ConstructorElement baseElement = this.baseElement;
    List<ParameterElement> parameters = this.parameters;
    FunctionType type = this.type;
    StringBuffer buffer = new StringBuffer();
    buffer.write(baseElement.enclosingElement.displayName);
    String name = displayName;
    if (name != null && !name.isEmpty) {
      buffer.write(".");
      buffer.write(name);
    }
    buffer.write("(");
    int parameterCount = parameters.length;
    for (int i = 0; i < parameterCount; i++) {
      if (i > 0) {
        buffer.write(", ");
      }
      buffer.write(parameters[i]);
    }
    buffer.write(")");
    if (type != null) {
      buffer.write(ElementImpl.RIGHT_ARROW);
      buffer.write(type.returnType);
    }
    return buffer.toString();
  }

  /**
   * If the given [constructor]'s type is different when any type parameters
   * from the defining type's declaration are replaced with the actual type
   * arguments from the [definingType], create a constructor member representing
   * the given constructor. Return the member that was created, or the original
   * constructor if no member was created.
   */
  static ConstructorElement from(
      ConstructorElement constructor, InterfaceType definingType) {
    if (constructor == null || definingType.typeArguments.length == 0) {
      return constructor;
    }
    FunctionType baseType = constructor.type;
    if (baseType == null) {
      // TODO(brianwilkerson) We need to understand when this can happen.
      return constructor;
    }
    List<DartType> argumentTypes = definingType.typeArguments;
    List<DartType> parameterTypes = definingType.element.type.typeArguments;
    FunctionType substitutedType =
        baseType.substitute2(argumentTypes, parameterTypes);
    if (baseType == substitutedType) {
      return constructor;
    }
    return new ConstructorMember(constructor, definingType, substitutedType);
  }
}

/**
 * An executable element defined in a parameterized type where the values of the
 * type parameters are known.
 */
abstract class ExecutableMember extends Member implements ExecutableElement {
  FunctionType _type;

  /**
   * Initialize a newly created element to represent a callable element (like a
   * method or function or property), based on the [baseElement], defined by the
   * [definingType]. If [type] is passed, it represents the full type of the
   * member, and will take precedence over the [definingType].
   */
  ExecutableMember(ExecutableElement baseElement, InterfaceType definingType,
      [FunctionType type])
      : _type = type,
        super(baseElement, definingType);

  @override
  ExecutableElement get baseElement => super.baseElement as ExecutableElement;

  @override
  List<FunctionElement> get functions {
    //
    // Elements within this element should have type parameters substituted,
    // just like this element.
    //
    throw new UnsupportedOperationException();
//    return getBaseElement().getFunctions();
  }

  @override
  bool get hasImplicitReturnType => baseElement.hasImplicitReturnType;

  @override
  bool get isAbstract => baseElement.isAbstract;

  @override
  bool get isAsynchronous => baseElement.isAsynchronous;

  @override
  bool get isExternal => baseElement.isExternal;

  @override
  bool get isGenerator => baseElement.isGenerator;

  @override
  bool get isOperator => baseElement.isOperator;

  @override
  bool get isStatic => baseElement.isStatic;

  @override
  bool get isSynchronous => baseElement.isSynchronous;

  @override
  List<LabelElement> get labels => baseElement.labels;

  @override
  List<LocalVariableElement> get localVariables {
    //
    // Elements within this element should have type parameters substituted,
    // just like this element.
    //
    throw new UnsupportedOperationException();
//    return getBaseElement().getLocalVariables();
  }

  @override
  List<ParameterElement> get parameters => type.parameters;

  @override
  DartType get returnType => type.returnType;

  @override
  FunctionType get type {
    return _type ??= baseElement.type.substitute2(definingType.typeArguments,
        TypeParameterTypeImpl.getTypes(definingType.typeParameters));
  }

  @override
  List<TypeParameterElement> get typeParameters => baseElement.typeParameters;

  @override
  void visitChildren(ElementVisitor visitor) {
    // TODO(brianwilkerson) We need to finish implementing the accessors used
    // below so that we can safely invoke them.
    super.visitChildren(visitor);
    safelyVisitChildren(baseElement.functions, visitor);
    safelyVisitChildren(labels, visitor);
    safelyVisitChildren(baseElement.localVariables, visitor);
    safelyVisitChildren(parameters, visitor);
  }
}

/**
 * A parameter element defined in a parameterized type where the values of the
 * type parameters are known.
 */
class FieldFormalParameterMember extends ParameterMember
    implements FieldFormalParameterElement {
  /**
   * Initialize a newly created element to represent a field formal parameter,
   * based on the [baseElement], defined by the [definingType]. If [type]
   * is passed it will be used as the substituted type for this member.
   */
  FieldFormalParameterMember(
      FieldFormalParameterElement baseElement, ParameterizedType definingType,
      [DartType type])
      : super(baseElement, definingType, type);

  @override
  FieldElement get field {
    FieldElement field = (baseElement as FieldFormalParameterElement).field;
    if (field is FieldElement) {
      return FieldMember.from(
          field, substituteFor(field.enclosingElement.type));
    }
    return field;
  }

  @override
  accept(ElementVisitor visitor) =>
      visitor.visitFieldFormalParameterElement(this);
}

/**
 * A field element defined in a parameterized type where the values of the type
 * parameters are known.
 */
class FieldMember extends VariableMember implements FieldElement {
  /**
   * Initialize a newly created element to represent a field, based on the
   * [baseElement], defined by the [definingType].
   */
  FieldMember(FieldElement baseElement, InterfaceType definingType)
      : super(baseElement, definingType);

  @override
  FieldElement get baseElement => super.baseElement as FieldElement;

  @override
  ClassElement get enclosingElement => baseElement.enclosingElement;

  @override
  PropertyAccessorElement get getter =>
      PropertyAccessorMember.from(baseElement.getter, definingType);

  @override
  bool get isEnumConstant => baseElement.isEnumConstant;

  @override
  DartType get propagatedType => substituteFor(baseElement.propagatedType);

  @override
  PropertyAccessorElement get setter =>
      PropertyAccessorMember.from(baseElement.setter, definingType);

  @override
  accept(ElementVisitor visitor) => visitor.visitFieldElement(this);

  @override
  VariableDeclaration computeNode() => baseElement.computeNode();

  @override
  String toString() => '$type $displayName';

  /**
   * If the given [field]'s type is different when any type parameters from the
   * defining type's declaration are replaced with the actual type arguments
   * from the [definingType], create a field member representing the given
   * field. Return the member that was created, or the base field if no member
   * was created.
   */
  static FieldElement from(FieldElement field, ParameterizedType definingType) {
    if (!_isChangedByTypeSubstitution(field, definingType)) {
      return field;
    }
    // TODO(brianwilkerson) Consider caching the substituted type in the
    // instance. It would use more memory but speed up some operations.
    // We need to see how often the type is being re-computed.
    return new FieldMember(field, definingType);
  }

  /**
   * Determine whether the given [field]'s type is changed when type parameters
   * from the [definingType]'s declaration are replaced with the actual type
   * arguments from the defining type.
   */
  static bool _isChangedByTypeSubstitution(
      FieldElement field, ParameterizedType definingType) {
    List<DartType> argumentTypes = definingType.typeArguments;
    if (field != null && argumentTypes.length != 0) {
      DartType baseType = field.type;
      List<DartType> parameterTypes =
          TypeParameterTypeImpl.getTypes(definingType.typeParameters);
      if (baseType != null) {
        DartType substitutedType =
            baseType.substitute2(argumentTypes, parameterTypes);
        if (baseType != substitutedType) {
          return true;
        }
      }
      // If the field has a propagated type, then we need to check whether the
      // propagated type needs substitution.
      DartType basePropagatedType = field.propagatedType;
      if (basePropagatedType != null) {
        DartType substitutedPropagatedType =
            basePropagatedType.substitute2(argumentTypes, parameterTypes);
        if (basePropagatedType != substitutedPropagatedType) {
          return true;
        }
      }
    }
    return false;
  }
}

/**
 * Deprecated: this type is no longer used. Use
 * [MethodInvocation.staticInvokeType] to get the instantiated type of a generic
 * method invocation.
 *
 * An element of a generic function, where the type parameters are known.
 */
// TODO(jmesserly): the term "function member" is a bit weird, but it allows
// a certain consistency.
@deprecated
class FunctionMember extends ExecutableMember implements FunctionElement {
  /**
   * Initialize a newly created element to represent a function, based on the
   * [baseElement], with the corresponding function [type].
   */
  @deprecated
  FunctionMember(FunctionElement baseElement, [DartType type])
      : super(baseElement, null, type);

  @override
  FunctionElement get baseElement => super.baseElement as FunctionElement;

  @override
  Element get enclosingElement => baseElement.enclosingElement;

  @override
  bool get isEntryPoint => baseElement.isEntryPoint;

  @override
  SourceRange get visibleRange => baseElement.visibleRange;

  @override
  accept(ElementVisitor visitor) => visitor.visitFunctionElement(this);

  @override
  FunctionDeclaration computeNode() => baseElement.computeNode();

  @override
  String toString() {
    StringBuffer buffer = new StringBuffer();
    buffer.write(baseElement.displayName);
    (type as FunctionTypeImpl).appendTo(buffer);
    return buffer.toString();
  }

  /**
   * If the given [method]'s type is different when any type parameters from the
   * defining type's declaration are replaced with the actual type arguments
   * from the [definingType], create a method member representing the given
   * method. Return the member that was created, or the base method if no member
   * was created.
   */
  static MethodElement from(
      MethodElement method, ParameterizedType definingType) {
    if (method == null || definingType.typeArguments.length == 0) {
      return method;
    }
    FunctionType baseType = method.type;
    List<DartType> argumentTypes = definingType.typeArguments;
    List<DartType> parameterTypes =
        TypeParameterTypeImpl.getTypes(definingType.typeParameters);
    FunctionType substitutedType =
        baseType.substitute2(argumentTypes, parameterTypes);
    if (baseType == substitutedType) {
      return method;
    }
    return new MethodMember(method, definingType, substitutedType);
  }
}

/**
 * An element defined in a parameterized type where the values of the type
 * parameters are known.
 */
abstract class Member implements Element {
  /**
   * The element on which the parameterized element was created.
   */
  final Element _baseElement;

  /**
   * The type in which the element is defined.
   */
  final ParameterizedType _definingType;

  /**
   * Initialize a newly created element to represent a member, based on the
   * [baseElement], defined by the [definingType].
   */
  Member(this._baseElement, this._definingType);

  /**
   * Return the element on which the parameterized element was created.
   */
  Element get baseElement => _baseElement;

  @override
  AnalysisContext get context => _baseElement.context;

  /**
   * Return the type in which the element is defined.
   */
  ParameterizedType get definingType => _definingType;

  @override
  String get displayName => _baseElement.displayName;

  @deprecated
  @override
  SourceRange get docRange => _baseElement.docRange;

  @override
  String get documentationComment => _baseElement.documentationComment;

  @override
  int get id => _baseElement.id;

  @override
  bool get isDeprecated => _baseElement.isDeprecated;

  @override
  bool get isOverride => _baseElement.isOverride;

  @override
  bool get isPrivate => _baseElement.isPrivate;

  @override
  bool get isProtected => _baseElement.isProtected;

  @override
  bool get isPublic => _baseElement.isPublic;

  @override
  bool get isSynthetic => _baseElement.isSynthetic;

  @override
  ElementKind get kind => _baseElement.kind;

  @override
  LibraryElement get library => _baseElement.library;

  @override
  ElementLocation get location => _baseElement.location;

  @override
  List<ElementAnnotation> get metadata => _baseElement.metadata;

  @override
  String get name => _baseElement.name;

  @override
  int get nameLength => _baseElement.nameLength;

  @override
  int get nameOffset => _baseElement.nameOffset;

  @override
  Source get source => _baseElement.source;

  @override
  CompilationUnit get unit => _baseElement.unit;

  @override
  String computeDocumentationComment() => documentationComment;

  @override
  AstNode computeNode() => _baseElement.computeNode();

  @override
  Element getAncestor(Predicate<Element> predicate) =>
      baseElement.getAncestor(predicate);

  @override
  String getExtendedDisplayName(String shortName) =>
      _baseElement.getExtendedDisplayName(shortName);

  @override
  bool isAccessibleIn(LibraryElement library) =>
      _baseElement.isAccessibleIn(library);

  /**
   * If the given [child] is not `null`, use the given [visitor] to visit it.
   */
  void safelyVisitChild(Element child, ElementVisitor visitor) {
    // TODO(brianwilkerson) Make this private
    if (child != null) {
      child.accept(visitor);
    }
  }

  /**
   * Use the given [visitor] to visit all of the [children].
   */
  void safelyVisitChildren(List<Element> children, ElementVisitor visitor) {
    // TODO(brianwilkerson) Make this private
    if (children != null) {
      for (Element child in children) {
        child.accept(visitor);
      }
    }
  }

  /**
   * Return the type that results from replacing the type parameters in the
   * given [type] with the type arguments associated with this member.
   */
  DartType substituteFor(DartType type) {
    if (type == null) {
      return null;
    }
    List<DartType> argumentTypes = _definingType.typeArguments;
    List<DartType> parameterTypes =
        TypeParameterTypeImpl.getTypes(_definingType.typeParameters);
    return type.substitute2(argumentTypes, parameterTypes);
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    // There are no children to visit
  }
}

/**
 * A method element defined in a parameterized type where the values of the type
 * parameters are known.
 */
class MethodMember extends ExecutableMember implements MethodElement {
  /**
   * Initialize a newly created element to represent a method, based on the
   * [baseElement], defined by the [definingType]. If [type] is passed, it
   * represents the full type of the member, and will take precedence over
   * the [definingType].
   */
  MethodMember(MethodElement baseElement, InterfaceType definingType,
      [DartType type])
      : super(baseElement, definingType, type);

  @override
  MethodElement get baseElement => super.baseElement as MethodElement;

  @override
  ClassElement get enclosingElement => baseElement.enclosingElement;

  @override
  accept(ElementVisitor visitor) => visitor.visitMethodElement(this);

  @override
  MethodDeclaration computeNode() => baseElement.computeNode();

  @override
  String toString() {
    MethodElement baseElement = this.baseElement;
    List<ParameterElement> parameters = this.parameters;
    FunctionType type = this.type;
    StringBuffer buffer = new StringBuffer();
    buffer.write(baseElement.enclosingElement.displayName);
    buffer.write(".");
    buffer.write(baseElement.displayName);
    buffer.write("(");
    int parameterCount = parameters.length;
    for (int i = 0; i < parameterCount; i++) {
      if (i > 0) {
        buffer.write(", ");
      }
      buffer.write(parameters[i]);
    }
    buffer.write(")");
    if (type != null) {
      buffer.write(ElementImpl.RIGHT_ARROW);
      buffer.write(type.returnType);
    }
    return buffer.toString();
  }

  /**
   * If the given [method]'s type is different when any type parameters from the
   * defining type's declaration are replaced with the actual type arguments
   * from the [definingType], create a method member representing the given
   * method. Return the member that was created, or the base method if no member
   * was created.
   */
  static MethodElement from(MethodElement method, InterfaceType definingType) {
    if (method == null || definingType.typeArguments.length == 0) {
      return method;
    }
    FunctionType baseType = method.type;
    List<DartType> argumentTypes = definingType.typeArguments;
    List<DartType> parameterTypes = definingType.element.type.typeArguments;
    FunctionType substitutedType =
        baseType.substitute2(argumentTypes, parameterTypes);
    if (baseType == substitutedType) {
      return method;
    }
    return new MethodMember(method, definingType, substitutedType);
  }
}

/**
 * A parameter element defined in a parameterized type where the values of the
 * type parameters are known.
 */
class ParameterMember extends VariableMember
    with ParameterElementMixin
    implements ParameterElement {
  /**
   * Initialize a newly created element to represent a parameter, based on the
   * [baseElement], defined by the [definingType]. If [type] is passed it will
   * represent the already substituted type.
   */
  ParameterMember(ParameterElement baseElement, ParameterizedType definingType,
      [DartType type])
      : super._(baseElement, definingType, type);

  @override
  ParameterElement get baseElement => super.baseElement as ParameterElement;

  @override
  String get defaultValueCode => baseElement.defaultValueCode;

  @override
  Element get enclosingElement => baseElement.enclosingElement;

  @override
  int get hashCode => baseElement.hashCode;

  @override
  bool get isInitializingFormal => baseElement.isInitializingFormal;

  @override
  ParameterKind get parameterKind => baseElement.parameterKind;

  @override
  List<ParameterElement> get parameters {
    DartType type = this.type;
    if (type is FunctionType) {
      return type.parameters;
    }
    return ParameterElement.EMPTY_LIST;
  }

  @override
  List<TypeParameterElement> get typeParameters => baseElement.typeParameters;

  @override
  SourceRange get visibleRange => baseElement.visibleRange;

  @override
  accept(ElementVisitor visitor) => visitor.visitParameterElement(this);

  @override
  FormalParameter computeNode() => baseElement.computeNode();

  @override
  Element getAncestor(Predicate<Element> predicate) {
    Element element = baseElement.getAncestor(predicate);
    ParameterizedType definingType = this.definingType;
    if (definingType is InterfaceType) {
      InterfaceType definingInterfaceType = definingType;
      if (element is ConstructorElement) {
        return ConstructorMember.from(element, definingInterfaceType);
      } else if (element is MethodElement) {
        return MethodMember.from(element, definingInterfaceType);
      } else if (element is PropertyAccessorElement) {
        return PropertyAccessorMember.from(element, definingInterfaceType);
      }
    }
    return element;
  }

  @override
  String toString() {
    ParameterElement baseElement = this.baseElement;
    String left = "";
    String right = "";
    while (true) {
      if (baseElement.parameterKind == ParameterKind.NAMED) {
        left = "{";
        right = "}";
      } else if (baseElement.parameterKind == ParameterKind.POSITIONAL) {
        left = "[";
        right = "]";
      } else if (baseElement.parameterKind == ParameterKind.REQUIRED) {}
      break;
    }
    return '$left$type ${baseElement.displayName}$right';
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    super.visitChildren(visitor);
    safelyVisitChildren(parameters, visitor);
  }

  /**
   * If the given [parameter]'s type is different when any type parameters from
   * the defining type's declaration are replaced with the actual type
   * arguments from the [definingType], create a parameter member representing
   * the given parameter. Return the member that was created, or the base
   * parameter if no member was created.
   */
  static ParameterElement from(
      ParameterElement parameter, ParameterizedType definingType) {
    if (parameter == null || definingType.typeArguments.length == 0) {
      return parameter;
    }
    // Check if parameter type depends on defining type type arguments.
    // It is possible that we did not resolve field formal parameter yet,
    // so skip this check for it.
    if (parameter is FieldFormalParameterElement) {
      return new FieldFormalParameterMember(parameter, definingType);
    } else {
      DartType baseType = parameter.type;
      List<DartType> argumentTypes = definingType.typeArguments;
      List<DartType> parameterTypes =
          TypeParameterTypeImpl.getTypes(definingType.typeParameters);
      DartType substitutedType =
          baseType.substitute2(argumentTypes, parameterTypes);
      if (baseType == substitutedType) {
        return parameter;
      }
      return new ParameterMember(parameter, definingType, substitutedType);
    }
  }
}

/**
 * A property accessor element defined in a parameterized type where the values
 * of the type parameters are known.
 */
class PropertyAccessorMember extends ExecutableMember
    implements PropertyAccessorElement {
  /**
   * Initialize a newly created element to represent a property, based on the
   * [baseElement], defined by the [definingType].
   */
  PropertyAccessorMember(
      PropertyAccessorElement baseElement, InterfaceType definingType)
      : super(baseElement, definingType);

  @override
  PropertyAccessorElement get baseElement =>
      super.baseElement as PropertyAccessorElement;

  @override
  PropertyAccessorElement get correspondingGetter =>
      from(baseElement.correspondingGetter, definingType);

  @override
  PropertyAccessorElement get correspondingSetter =>
      from(baseElement.correspondingSetter, definingType);

  @override
  InterfaceType get definingType => super.definingType as InterfaceType;

  @override
  Element get enclosingElement => baseElement.enclosingElement;

  @override
  bool get isGetter => baseElement.isGetter;

  @override
  bool get isSetter => baseElement.isSetter;

  @override
  PropertyInducingElement get variable {
    PropertyInducingElement variable = baseElement.variable;
    if (variable is FieldElement) {
      return FieldMember.from(variable, definingType);
    }
    return variable;
  }

  @override
  accept(ElementVisitor visitor) => visitor.visitPropertyAccessorElement(this);

  @override
  String toString() {
    PropertyAccessorElement baseElement = this.baseElement;
    List<ParameterElement> parameters = this.parameters;
    FunctionType type = this.type;
    StringBuffer builder = new StringBuffer();
    if (isGetter) {
      builder.write("get ");
    } else {
      builder.write("set ");
    }
    builder.write(baseElement.enclosingElement.displayName);
    builder.write(".");
    builder.write(baseElement.displayName);
    builder.write("(");
    int parameterCount = parameters.length;
    for (int i = 0; i < parameterCount; i++) {
      if (i > 0) {
        builder.write(", ");
      }
      builder.write(parameters[i]);
    }
    builder.write(")");
    if (type != null) {
      builder.write(ElementImpl.RIGHT_ARROW);
      builder.write(type.returnType);
    }
    return builder.toString();
  }

  /**
   * If the given [accessor]'s type is different when any type parameters from
   * the defining type's declaration are replaced with the actual type
   * arguments from the [definingType], create an accessor member representing
   * the given accessor. Return the member that was created, or the base
   * accessor if no member was created.
   */
  static PropertyAccessorElement from(
      PropertyAccessorElement accessor, InterfaceType definingType) {
    if (!_isChangedByTypeSubstitution(accessor, definingType)) {
      return accessor;
    }
    // TODO(brianwilkerson) Consider caching the substituted type in the
    // instance. It would use more memory but speed up some operations.
    // We need to see how often the type is being re-computed.
    return new PropertyAccessorMember(accessor, definingType);
  }

  /**
   * Determine whether the given property [accessor]'s type is changed when type
   * parameters from the defining type's declaration are replaced with the
   * actual type arguments from the [definingType].
   */
  static bool _isChangedByTypeSubstitution(
      PropertyAccessorElement accessor, InterfaceType definingType) {
    List<DartType> argumentTypes = definingType.typeArguments;
    if (accessor != null && argumentTypes.length != 0) {
      FunctionType baseType = accessor.type;
      if (baseType == null) {
        AnalysisEngine.instance.logger.logInformation(
            'Type of $accessor is null in PropertyAccessorMember._isChangedByTypeSubstitution');
        return false;
      }
      List<DartType> parameterTypes = definingType.element.type.typeArguments;
      FunctionType substitutedType =
          baseType.substitute2(argumentTypes, parameterTypes);
      if (baseType != substitutedType) {
        return true;
      }
      // If this property accessor is based on a field, that field might have a
      // propagated type. In which case we need to check whether the propagated
      // type of the field needs substitution.
      PropertyInducingElement field = accessor.variable;
      if (!field.isSynthetic) {
        DartType baseFieldType = field.propagatedType;
        if (baseFieldType != null) {
          DartType substitutedFieldType =
              baseFieldType.substitute2(argumentTypes, parameterTypes);
          if (baseFieldType != substitutedFieldType) {
            return true;
          }
        }
      }
    }
    return false;
  }
}

/**
 * A type parameter defined inside of another parameterized type, where the
 * values of the enclosing type parameters are known.
 *
 * For example:
 *
 *     class C<T> {
 *       S m<S extends T>(S s);
 *     }
 *
 * If we have `C<num>.m` and we ask for the type parameter "S", we should get
 * `<S extends num>` instead of `<S extends T>`. This is how the parameter
 * and return types work, see: [FunctionType.parameters],
 * [FunctionType.returnType], and [ParameterMember].
 */
class TypeParameterMember extends Member implements TypeParameterElement {
  @override
  final DartType bound;

  TypeParameterMember(
      TypeParameterElement baseElement, DartType definingType, this.bound)
      : super(baseElement, definingType);

  @override
  TypeParameterElement get baseElement =>
      super.baseElement as TypeParameterElement;

  @override
  Element get enclosingElement => baseElement.enclosingElement;

  @override
  TypeParameterType get type => baseElement.type;

  @override
  accept(ElementVisitor visitor) => visitor.visitTypeParameterElement(this);

  /**
   * If the given [parameter]'s type is different when any type parameters from
   * the defining type's declaration are replaced with the actual type
   * arguments from the [definingType], create a parameter member representing
   * the given parameter. Return the member that was created, or the base
   * parameter if no member was created.
   */
  static TypeParameterElement from(
      TypeParameterElement parameter, ParameterizedType definingType) {
    if (parameter?.bound == null || definingType.typeArguments.isEmpty) {
      return parameter;
    }

    DartType bound = parameter.bound;
    List<DartType> argumentTypes = definingType.typeArguments;
    List<DartType> parameterTypes =
        TypeParameterTypeImpl.getTypes(definingType.typeParameters);
    DartType substitutedBound =
        bound.substitute2(argumentTypes, parameterTypes);
    if (bound == substitutedBound) {
      return parameter;
    }
    return new TypeParameterMember(parameter, definingType, substitutedBound);
  }
}

/**
 * A variable element defined in a parameterized type where the values of the
 * type parameters are known.
 */
abstract class VariableMember extends Member implements VariableElement {
  @override
  final DartType type;

  /**
   * Initialize a newly created element to represent a variable, based on the
   * [baseElement], defined by the [definingType].
   */
  VariableMember(VariableElement baseElement, ParameterizedType definingType,
      [DartType type])
      : type = type ??
            baseElement.type.substitute2(definingType.typeArguments,
                TypeParameterTypeImpl.getTypes(definingType.typeParameters)),
        super(baseElement, definingType);

  // TODO(jmesserly): this is temporary to allow the ParameterMember subclass.
  // Apparently mixins don't work with optional params.
  VariableMember._(VariableElement baseElement, ParameterizedType definingType,
      DartType type)
      : this(baseElement, definingType, type);

  @override
  VariableElement get baseElement => super.baseElement as VariableElement;

  @override
  DartObject get constantValue => baseElement.constantValue;

  @override
  bool get hasImplicitType => baseElement.hasImplicitType;

  @override
  FunctionElement get initializer {
    //
    // Elements within this element should have type parameters substituted,
    // just like this element.
    //
    throw new UnsupportedOperationException();
    //    return getBaseElement().getInitializer();
  }

  @override
  bool get isConst => baseElement.isConst;

  @override
  bool get isFinal => baseElement.isFinal;

  @override
  bool get isPotentiallyMutatedInClosure =>
      baseElement.isPotentiallyMutatedInClosure;

  @override
  bool get isPotentiallyMutatedInScope =>
      baseElement.isPotentiallyMutatedInScope;

  @override
  bool get isStatic => baseElement.isStatic;

  @override
  void visitChildren(ElementVisitor visitor) {
    // TODO(brianwilkerson) We need to finish implementing the accessors used
    // below so that we can safely invoke them.
    super.visitChildren(visitor);
    safelyVisitChild(baseElement.initializer, visitor);
  }
}
