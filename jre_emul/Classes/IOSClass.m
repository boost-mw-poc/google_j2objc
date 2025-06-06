// Copyright 2011 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//
//  IOSClass.m
//  JreEmulation
//
//  Created by Tom Ball on 10/18/11.
//

#import "IOSClass.h"
#import "J2ObjC_source.h"

#import "FastPointerLookup.h"
#import "IOSArrayClass.h"
#import "IOSConcreteClass.h"
#import "IOSObjectArray.h"
#import "IOSPrimitiveArray.h"
#import "IOSPrimitiveClass.h"
#import "IOSProtocolClass.h"
#import "IOSProxyClass.h"
#import "IOSReflection.h"
#import "NSCopying+JavaCloneable.h"
#import "NSDataInputStream.h"
#import "NSNumber+JavaNumber.h"
#import "NSObject+JavaObject.h"
#import "NSString+JavaString.h"
#import "com/google/j2objc/ReflectionStrippedError.h"
#import "java/lang/AssertionError.h"
#import "java/lang/ClassCastException.h"
#import "java/lang/ClassLoader.h"
#import "java/lang/ClassNotFoundException.h"
#import "java/lang/Enum.h"
#import "java/lang/InstantiationException.h"
#import "java/lang/NoSuchFieldException.h"
#import "java/lang/NoSuchMethodException.h"
#import "java/lang/NullPointerException.h"
#import "java/lang/Package.h"
#import "java/lang/Record.h"
#import "java/lang/StringBuilder.h"
#import "java/lang/annotation/Annotation.h"
#import "java/lang/annotation/Inherited.h"
#import "java/lang/reflect/Constructor.h"
#import "java/lang/reflect/Field.h"
#import "java/lang/reflect/Method.h"
#import "java/lang/reflect/Modifier.h"
#import "java/lang/reflect/RecordComponent.h"
#import "java/lang/reflect/TypeVariable.h"
#import "java/util/ArrayList.h"
#import "java/util/Iterator.h"
#import "java/util/Properties.h"
#import "java/util/Set.h"
#import "libcore/reflect/AnnotatedElements.h"
#import "libcore/reflect/GenericSignatureParser.h"
#import "libcore/reflect/Types.h"

#import "objc/message.h"
#import "objc/runtime.h"

#define IOSClass_serialVersionUID 3206093459760846163LL

@interface IOSClass () {
  const J2ObjcClassInfo *metadata_;
}
@end

J2OBJC_INITIALIZED_DEFN(IOSClass)

#define PREFIX_MAPPING_RESOURCE @"/prefixes.properties"

// Package to prefix mappings, initialized in FindRenamedPackagePrefix().
static JavaUtilArrayList *prefixMapping;

@interface PackagePrefixEntry : NSObject {
  NSString *key_;
  NSString *value_;
}
- (instancetype)initWithNSString:(NSString *)key withNSString:(NSString *)value;
- (NSString *)key;
- (NSString *)value;
@end

@interface PackagePrefixLoader : NSObject < JavaUtilProperties_KeyValueLoader >
- (void)load__WithNSString:(NSString *)key withNSString:(NSString *)value;
@end

@implementation IOSClass

// Primitive class instances.
static IOSPrimitiveClass *IOSClass_byteClass;
static IOSPrimitiveClass *IOSClass_charClass;
static IOSPrimitiveClass *IOSClass_doubleClass;
static IOSPrimitiveClass *IOSClass_floatClass;
static IOSPrimitiveClass *IOSClass_intClass;
static IOSPrimitiveClass *IOSClass_longClass;
static IOSPrimitiveClass *IOSClass_shortClass;
static IOSPrimitiveClass *IOSClass_booleanClass;
static IOSPrimitiveClass *IOSClass_voidClass;

// Other commonly used instances.
static IOSClass *IOSClass_objectClass;

static IOSObjectArray *IOSClass_emptyClassArray;

- (Class)objcClass {
  return nil;
}

- (Protocol *)objcProtocol {
  return nil;
}

+ (IOSClass *)byteClass {
  return IOSClass_byteClass;
}

+ (IOSClass *)charClass {
  return IOSClass_charClass;
}

+ (IOSClass *)doubleClass {
  return IOSClass_doubleClass;
}

+ (IOSClass *)floatClass {
  return IOSClass_floatClass;
}

+ (IOSClass *)intClass {
  return IOSClass_intClass;
}

+ (IOSClass *)longClass {
  return IOSClass_longClass;
}

+ (IOSClass *)shortClass {
  return IOSClass_shortClass;
}

+ (IOSClass *)booleanClass {
  return IOSClass_booleanClass;
}

+ (IOSClass *)voidClass {
  return IOSClass_voidClass;
}

- (instancetype)initWithMetadata:(const J2ObjcClassInfo *)metadata {
  if ((self = [super init])) {
    metadata_ = metadata;
  }
  return self;
}

- (id)newInstance {
  // Per the JLS spec, throw an InstantiationException if the type is an
  // interface (no class_), array or primitive type (IOSClass types), or void.
  @throw AUTORELEASE([[JavaLangInstantiationException alloc] init]);
}

const J2ObjcClassInfo *IOSClass_GetMetadataOrFail(IOSClass *iosClass) {
  const J2ObjcClassInfo *metadata = iosClass->metadata_;
  if (metadata) {
    return metadata;
  }
  @throw create_ComGoogleJ2objcReflectionStrippedError_initWithIOSClass_(iosClass);
}

- (IOSClass *)getSuperclass {
  return nil;
}

// Returnes a SignatureParser with the already parsed generic class signatur or null if there is no
// generic signature. The returned SignatureParser must be released by the caller.
static LibcoreReflectGenericSignatureParser *NewParsedClassSignature(IOSClass *cls) {
  const J2ObjcClassInfo *metadata = cls->metadata_;
  if (!metadata) {
    return nil;
  }
  const char *signature = JrePtrAtIndex(metadata->ptrTable, metadata->genericSignatureIdx);
  if (!signature) {
    return nil;
  }
  LibcoreReflectGenericSignatureParser *parser =
      new_LibcoreReflectGenericSignatureParser_initWithJavaLangClassLoader_(
          JavaLangClassLoader_getSystemClassLoader());
  [parser parseForClassWithJavaLangReflectGenericDeclaration:cls
      withNSString:[NSString stringWithUTF8String:signature]];
  return parser;
}

- (id<JavaLangReflectType>)getGenericSuperclass {
  id<JavaLangReflectType> result = [self getSuperclass];
  if (!result) {
    return nil;
  }
  LibcoreReflectGenericSignatureParser *parser = NewParsedClassSignature(self);
  if (parser) {
    result = [LibcoreReflectTypes getType:parser->superclassType_];
    [parser release];
  }
  return result;
}

- (IOSClass *)getDeclaringClass {
  if ([self isPrimitive] || [self isArray] || [self isAnonymousClass] || [self isLocalClass]) {
    // Class.getDeclaringClass() javadoc, JVM spec 4.7.6.
    return nil;
  }
  IOSClass *enclosingClass = [self getEnclosingClass];
  while ([enclosingClass isAnonymousClass]) {
    enclosingClass = [enclosingClass getEnclosingClass];
  }
  return enclosingClass;
}

// Returns true if an object is an instance of this class.
- (bool)isInstance:(id)object {
  return false;
}

- (NSString *)getName {
  @throw create_JavaLangAssertionError_initWithId_(@"abstract method not overridden");
}

- (NSString *)getSimpleName {
  return [self getName];
}

- (NSString *)getCanonicalName {
  return [[self getName] stringByReplacingOccurrencesOfString:@"$" withString:@"."];
}

- (NSString *)objcName {
  @throw create_JavaLangAssertionError_initWithId_(@"abstract method not overridden");
}

- (void)appendMetadataName:(NSMutableString *)str {
  @throw create_JavaLangAssertionError_initWithId_(@"abstract method not overridden");
}

- (jint)getModifiers {
  if (metadata_) {
    return metadata_->modifiers & JavaLangReflectModifier_classModifiers();
  } else {
    // All Objective-C classes and protocols are public by default.
    return JavaLangReflectModifier_PUBLIC;
  }
}

static void GetMethodsFromClass(IOSClass *iosClass, NSMutableDictionary *methods, bool publicOnly) {
  const J2ObjcClassInfo *metadata = IOSClass_GetMetadataOrFail(iosClass);
  if (metadata->methodCount == 0) {
    return;
  }
  for (int i = 0; i < metadata->methodCount; i++) {
    const J2ObjcMethodInfo *methodInfo = &metadata->methods[i];
    if (!methodInfo->returnType) {  // constructor.
      continue;
    }
    if (publicOnly && (methodInfo->modifiers & JavaLangReflectModifier_PUBLIC) == 0) {
      continue;
    }
    NSString *selector = NSStringFromSelector(methodInfo->selector);
    if ([methods valueForKey:selector]) {
      continue;
    }
    JavaLangReflectMethod *method =
        [JavaLangReflectMethod methodWithDeclaringClass:iosClass
                                               metadata:methodInfo];
    [methods setObject:method forKey:selector];
  }
}

// Return the class and instance methods declared by the Java class.  Superclass
// methods are not included.
- (IOSObjectArray *)getDeclaredMethods {
  NSMutableDictionary *methodMap = [NSMutableDictionary dictionary];
  GetMethodsFromClass(self, methodMap, false);
  return [IOSObjectArray arrayWithNSArray:[methodMap allValues]
      type:JavaLangReflectMethod_class_()];
}

// Return the constructors declared by this class.  Superclass constructors
// are not included.
- (IOSObjectArray *)getDeclaredConstructors {
  return [IOSObjectArray arrayWithLength:0 type:JavaLangReflectConstructor_class_()];
}

static void GetAllMethods(IOSClass *cls, NSMutableDictionary *methodMap) {
  GetMethodsFromClass(cls, methodMap, true);

  // getMethods() returns unimplemented interface methods if the class is
  // abstract and default interface methods that aren't overridden.
  for (IOSClass *p in [cls getInterfacesInternal]) {
    GetAllMethods(p, methodMap);
  }

  while ((cls = [cls getSuperclass])) {
    GetAllMethods(cls, methodMap);
  }
}

// Return the methods for this class, including inherited methods.
- (IOSObjectArray *)getMethods {
  NSMutableDictionary *methodMap = [NSMutableDictionary dictionary];
  GetAllMethods(self, methodMap);
  return [IOSObjectArray arrayWithNSArray:[methodMap allValues]
                                     type:JavaLangReflectMethod_class_()];
}

// Return the constructors for this class, including inherited ones.
- (IOSObjectArray *)getConstructors {
  return [IOSObjectArray arrayWithLength:0 type:JavaLangReflectConstructor_class_()];
}

// Return a method instance described by a name and an array of
// parameter types.  If the named method isn't a member of the specified
// class, return a superclass method if available.
- (JavaLangReflectMethod *)getMethod:(NSString *)name
                      parameterTypes:(IOSObjectArray *)types {
  (void)nil_chk(name);
  JavaLangReflectMethod *method = JreMethodWithNameAndParamTypesInherited(self, name, types);
  if (method && ([method getModifiers] & JavaLangReflectModifier_PUBLIC) > 0) {
    return method;
  }
  @throw create_JavaLangNoSuchMethodException_initWithNSString_(name);
}

// Return a method instance described by a name and an array of parameter
// types.  Return nil if the named method is not a member of this class.
- (JavaLangReflectMethod *)getDeclaredMethod:(NSString *)name
                              parameterTypes:(IOSObjectArray *)types {
  JavaLangReflectMethod *method = JreMethodWithNameAndParamTypes(self, name, types);
  if (method) {
    return method;
  }
  @throw create_JavaLangNoSuchMethodException_initWithNSString_(name);
}

- (JavaLangReflectMethod *)getMethodWithSelector:(const char *)selector {
  return JreMethodForSelectorInherited(self, sel_registerName(selector));
}

static NSString *Capitalize(NSString *s) {
  if ([s length] == 0) {
    return s;
  }
  // Only capitalize the first character, as NSString.capitalizedString
  // will make all other characters lowercase.
  NSString *firstChar = [[s substringToIndex:1] capitalizedString];
  return [s stringByReplacingCharactersInRange:NSMakeRange(0, 1)
                                    withString:firstChar];
}

- (IOSClass *)getComponentType {
  return nil;
}

- (JavaLangReflectConstructor *)getConstructor:(IOSObjectArray *)parameterTypes {
  // Java's getConstructor() only returns the constructor if it's public.
  // However, all constructors in Objective-C are public, so this method
  // is identical to getDeclaredConstructor().
  @throw create_JavaLangNoSuchMethodException_init();
}

- (JavaLangReflectConstructor *)getDeclaredConstructor:(IOSObjectArray *)parameterTypes {
  @throw create_JavaLangNoSuchMethodException_init();
}

- (bool)isAssignableFrom:(IOSClass *)cls {
  @throw create_JavaLangAssertionError_initWithId_(@"abstract method not overridden");
}

- (IOSClass *)asSubclass:(IOSClass *)cls {
  if ([cls isAssignableFrom:self]) {
    return self;
  }

  @throw create_JavaLangClassCastException_initWithNSString_([self description]);
}

- (NSString *)description {
  // matches java.lang.Class.toString() output
  return [NSString stringWithFormat:@"class %@", [self getName]];
}

- (NSString *)toGenericString {
  // Translation of Java method in Android libcore's java/lang/Class.java.
  if ([self isPrimitive]) {
    return [self description];
  }
  else {
    JavaLangStringBuilder *sb = create_JavaLangStringBuilder_init();
    jint modifiers = [self getModifiers] & JavaLangReflectModifier_classModifiers();
    if (modifiers != 0) {
      [sb appendWithNSString:JavaLangReflectModifier_toStringWithInt_(modifiers)];
      [sb appendWithChar:' '];
    }
    if ([self isAnnotation]) {
      [sb appendWithChar:'@'];
    }
    if ([self isInterface]) {
      [sb appendWithNSString:@"interface"];
    }
    else {
      if ([self isEnum]) {
        [sb appendWithNSString:@"enum"];
      } else {
        [sb appendWithNSString:@"class"];
      }
    }
    [sb appendWithChar:' '];
    [sb appendWithNSString:[self getName]];
    IOSObjectArray *typeparms = [self getTypeParameters];
    if (((IOSObjectArray *) nil_chk(typeparms))->size_ > 0) {
      bool first = true;
      [sb appendWithChar:'<'];
      for (id<JavaLangReflectTypeVariable> typeparm in typeparms) {
        if (!first) {
          [sb appendWithChar:','];
        }
        [sb appendWithNSString:[((id<JavaLangReflectTypeVariable>) nil_chk(typeparm)) getTypeName]];
        first = false;
      }
      [sb appendWithChar:'>'];
    }
    return [sb description];
  }
}

- (NSString *)binaryName {
  NSString *name = [self getName];
  return [NSString stringWithFormat:@"L%@;", name];
}

static NSString *CamelCasePackage(NSString *package) {
  NSArray *parts = [package componentsSeparatedByString:@"."];
  NSMutableString *result = [NSMutableString string];
  for (NSString *part in parts) {
    [result appendString:Capitalize(part)];
  }
  return result;
}

static IOSClass *ClassForIosName(NSString *iosName) {
  (void)nil_chk(iosName);
  // Some protocols have a sibling class that contains the metadata and any
  // constants that are defined. We must look for the protocol before the class
  // to ensure we create a IOSProtocolClass for such cases. NSObject must be
  // special-cased because it also has a protocol but we want to return an
  // IOSConcreteClass instance for it.
  if ([iosName isEqualToString:@"NSObject"]) {
    return IOSClass_objectClass;
  }
  Protocol *protocol = NSProtocolFromString(iosName);
  if (protocol) {
    return IOSClass_fromProtocol(protocol);
  }
  Class clazz = NSClassFromString(iosName);
  if (clazz) {
    return IOSClass_fromClass(clazz);
  }
  return nil;
}

static NSString *FindRenamedPackagePrefix(NSString *package) {
  NSString *prefix = nil;

  // Check for a package-info class that has a __prefix method.
  NSString *pkgInfoName = [CamelCasePackage(package) stringByAppendingString:@"package_info"];
  Class pkgInfoCls = NSClassFromString(pkgInfoName);
  Method prefixMethod = JreFindClassMethod(pkgInfoCls, sel_registerName("__prefix"));
  if (prefixMethod) {
    static NSString *(*method_invoke_prefix)(Class, Method) =
        (NSString * (*)(Class, Method)) method_invoke;
    prefix = method_invoke_prefix(pkgInfoCls, prefixMethod);
  }
  if (!prefix) {
    // Initialize prefix mappings, if defined.
    static dispatch_once_t once;
    dispatch_once(&once, ^{
      JavaIoInputStream *prefixesResource =
          [IOSClass_objectClass getResourceAsStream:PREFIX_MAPPING_RESOURCE];
      if (prefixesResource) {
        JreStrongAssignAndConsume(&prefixMapping, new_JavaUtilArrayList_init());
        JavaUtilProperties_LineReader *lr =
            create_JavaUtilProperties_LineReader_initWithJavaIoInputStream_(prefixesResource);
        PackagePrefixLoader *loader = [[PackagePrefixLoader alloc] init];
        [JavaUtilProperties loadLineReaderWithJavaUtilProperties_LineReader:lr
                                      withJavaUtilProperties_KeyValueLoader:loader];
        [loader release];
      }
    });
  }
  if (!prefix && prefixMapping) {
    // Check each prefix mapping to see if it's a matching wildcard.
    id<JavaUtilIterator> names = [prefixMapping iterator];
    while ([names hasNext]) {
      PackagePrefixEntry *entry = (PackagePrefixEntry *)[names next];
      NSString *key = [entry key];
      // Same translation as j2objc's PackagePrefixes.wildcardToRegex().
      NSString *regex;
      if ([key hasSuffix:@".*"]) {
        NSString *root = [[key java_substring:0 endIndex:((jint) [key length]) - 2]
                          java_replace:@"." withSequence:@"\\."];
        regex = [NSString stringWithFormat:@"^(%@|%@\\..*)$", root, root];
      } else {
        regex = [NSString stringWithFormat:@"^%@$",
                 [[key java_replace:@"." withSequence:@"\\."]
                  java_replace:@"\\*" withSequence:@".*"]];
      }
      if ([package java_matches:regex]) {
        prefix = [entry value];
        break;
      }
    }
  }
  return prefix;
}

+ (IOSClass *)classForIosName:(NSString *)iosName {
  return ClassForIosName(iosName);
}

static NSString *JavaToIosName(NSString *javaName) {
  if ([javaName isEqualToString:@"package-info"]) {
    return @"package_info";
  }
  return [javaName stringByReplacingOccurrencesOfString:@"$" withString:@"_"];
}

// The __j2objc_aliases custom data segment is built by the linker (along with these start
// and end section symbols) from structures defined by the J2OBJC_NAME_MAPPING macro.
// This data defines mapping for Java names to the actual iOS names, and so is only
// necessary when loading classes by name.
static NSDictionary *FetchNameMappings() {
  extern J2ObjcNameMapping start_alias_section __asm("section$start$__DATA$__j2objc_aliases");
  extern J2ObjcNameMapping end_alias_section  __asm("section$end$__DATA$__j2objc_aliases");
  NSUInteger nMappings = (NSUInteger)(&end_alias_section - &start_alias_section);
  NSMutableDictionary *mappedNames = [[NSMutableDictionary alloc] initWithCapacity:nMappings];
  for (long i = 0; i < nMappings; i++) {
    J2ObjcNameMapping* mapping = (&start_alias_section) + i;
    [mappedNames setObject:@(mapping->ios_name) forKey:@(mapping->java_name)];
  }
  return mappedNames;
}

static IOSClass *ClassForJavaName(NSString *name) {
  static NSDictionary *mappedNames;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    mappedNames = FetchNameMappings();
  });

  // First check if this is a mapped name.
  NSString *mappedName = [mappedNames objectForKey:name];
  if (mappedName) {
    return ClassForIosName(mappedName);
  }
  // Then check if any outer class is a mapped name.
  NSUInteger lastDollar = name.length;
  while (true) {
    lastDollar = [name rangeOfString:@"$"
                             options:NSBackwardsSearch
                               range:NSMakeRange(0, lastDollar)].location;
    if (lastDollar == NSNotFound) {
      break;
    }
    NSString *prefix = [name substringToIndex:lastDollar];
    NSString *mappedName = [mappedNames objectForKey:prefix];
    if (mappedName) {
      NSString *suffix = JavaToIosName([name substringFromIndex:lastDollar]);
      return ClassForIosName([mappedName stringByAppendingString:suffix]);
    }
  }

  // Separate package from class names.
  NSUInteger lastDot = [name rangeOfString:@"." options:NSBackwardsSearch].location;
  if (lastDot == NSNotFound) {
    // Empty package.
    return ClassForIosName(JavaToIosName(name));
  }
  NSString *package = [name substringToIndex:lastDot];
  NSString *clazz = JavaToIosName([name substringFromIndex:lastDot + 1]);
  // First check if the class can be found with the default camel case package. This avoids the
  // expensive FindRenamedPackagePrefix if possible.
  IOSClass *cls = ClassForIosName([CamelCasePackage(package) stringByAppendingString:clazz]);
  if (cls) {
    return cls;
  }
  // Check if the package has a mapped name.
  mappedName = [mappedNames objectForKey:package];
  if (mappedName) {
    return ClassForIosName([mappedName stringByAppendingString:clazz]);
  }
  // Check if the package has a renamed prefix.
  NSString *renamedPackage = FindRenamedPackagePrefix(package);
  if (renamedPackage) {
    return ClassForIosName([renamedPackage stringByAppendingString:clazz]);
  }
  return nil;
}

static IOSClass *IOSClass_PrimitiveClassForChar(unichar c) {
  switch (c) {
    case 'B': return IOSClass_byteClass;
    case 'C': return IOSClass_charClass;
    case 'D': return IOSClass_doubleClass;
    case 'F': return IOSClass_floatClass;
    case 'I': return IOSClass_intClass;
    case 'J': return IOSClass_longClass;
    case 'S': return IOSClass_shortClass;
    case 'Z': return IOSClass_booleanClass;
    case 'V': return IOSClass_voidClass;
    default: return nil;
  }
}

+ (IOSClass *)primitiveClassForChar:(unichar)c {
  return IOSClass_PrimitiveClassForChar(c);
}

static IOSClass *IOSClass_ArrayClassForName(NSString *name, NSUInteger index) {
  IOSClass *componentType = nil;
  unichar c = [name characterAtIndex:index];
  switch (c) {
    case 'L':
      {
        NSUInteger length = [name length];
        if ([name characterAtIndex:length - 1] == ';') {
          componentType = ClassForJavaName(
              [name substringWithRange:NSMakeRange(index + 1, length - index - 2)]);
        }
        break;
      }
    case '[':
      componentType = IOSClass_ArrayClassForName(name, index + 1);
      break;
    default:
      if ([name length] == index + 1) {
        componentType = IOSClass_PrimitiveClassForChar(c);
      }
      break;
  }
  if (componentType) {
    return IOSClass_arrayOf(componentType);
  }
  return nil;
}

IOSClass *IOSClass_forName_(NSString *className) {
  IOSClass_initialize();
  (void)nil_chk(className);
  IOSClass *iosClass = nil;
  if ([className length] > 0) {
    if ([className characterAtIndex:0] == '[') {
      iosClass = IOSClass_ArrayClassForName(className, 1);
    } else {
      iosClass = ClassForJavaName(className);
    }
  }
  if (iosClass) {
    [iosClass.objcClass class];  // Force initialization.
    return iosClass;
  }
  @throw AUTORELEASE([[JavaLangClassNotFoundException alloc] initWithNSString:className]);
}

+ (IOSClass *)forName:(NSString *)className {
  return IOSClass_forName_(className);
}

IOSClass *IOSClass_forName_initialize_classLoader_(NSString *className, bool load,
                                                   JavaLangClassLoader *loader) {
  IOSClass_initialize();
  return IOSClass_forName_(className);
}

+ (IOSClass *)forName:(NSString *)className
           initialize:(bool)load
          classLoader:(JavaLangClassLoader *)loader {
  return IOSClass_forName_initialize_classLoader_(className, load, loader);
}

- (id)cast:(id)object {
  if (__builtin_expect(object && ![self isInstance:object], 0)) {
    @throw create_JavaLangClassCastException_initWithNSString_(
        [NSString stringWithFormat:@"Cannot cast object of type %@ to %@",
            [[object java_getClass] getName], [self getName]]);
  }
  return object;
}

- (IOSClass *)getEnclosingClass {
  const J2ObjcClassInfo *metadata = IOSClass_GetMetadataOrFail(self);
  const char *enclosingClass = JrePtrAtIndex(metadata->ptrTable, metadata->enclosingClassIdx);
  return enclosingClass ? JreClassForString(enclosingClass) : nil;
}

- (bool)isArray {
  return false;
}

- (bool)isEnum {
  return false;
}

- (bool)isRecord {
  return [self getSuperclass] == JavaLangRecord_class_();
}

- (bool)isInterface {
  return false;
}

- (bool)isPrimitive {
  return false;  // Overridden by IOSPrimitiveClass.
}

static bool hasModifier(IOSClass *cls, int flag) {
  return cls->metadata_ ? (cls->metadata_->modifiers & flag) > 0 : false;
}

- (bool)isAnnotation {
  return hasModifier(self, JavaLangReflectModifier_ANNOTATION);
}

- (bool)isMemberClass {
  return metadata_ && JrePtrAtIndex(metadata_->ptrTable, metadata_->enclosingClassIdx)
      && ![self isAnonymousClass];
}

- (bool)isLocalClass {
  return [self getEnclosingMethod] && ![self isAnonymousClass];
}

- (bool)isSynthetic {
  return hasModifier(self, JavaLangReflectModifier_SYNTHETIC);
}

- (IOSObjectArray *)getInterfacesInternal {
  return IOSClass_emptyClassArray;
}

- (IOSObjectArray *)getInterfaces {
  return [IOSObjectArray arrayWithArray:[self getInterfacesInternal]];
}

- (IOSObjectArray *)getGenericInterfaces {
  LibcoreReflectGenericSignatureParser *parser = NewParsedClassSignature(self);
  if (parser) {
    IOSObjectArray *result = [LibcoreReflectTypes getTypeArray:parser->interfaceTypes_ clone:false];
    [parser release];
    return result;
  }
  // Just return regular interfaces list.
  IOSObjectArray *interfaces = [self getInterfacesInternal];
  return [IOSObjectArray arrayWithObjects:interfaces->buffer_
                                    count:interfaces->size_
                                     type:JavaLangReflectType_class_()];
}

// Checks if a ObjC protocol is a translated Java interface.
bool IsJavaInterface(Protocol *protocol, bool excludeNSCopying) {
  if (protocol == @protocol(NSCopying)) {
    return !excludeNSCopying;
  }
  unsigned int count;
  Protocol **protocolList = protocol_copyProtocolList(protocol, &count);
  bool result = false;
  // Every translated Java interface has JavaObject as the last inherited protocol.
  // Every translated Java annotation has JavaLangAnnotationAnnotation as its only inherited
  // protocol.
  for (unsigned int i = 0; i < count; i++) {
    if (protocolList[i] == @protocol(JavaObject)
        || protocolList[i] == @protocol(JavaLangAnnotationAnnotation)) {
      result = true;
      break;
    }
  }
  free(protocolList);
  return result;
}

IOSObjectArray *IOSClass_NewInterfacesFromProtocolList(
    Protocol **list, unsigned int count, bool excludeNSCopying) {
  IOSClass *buffer[count];
  unsigned int actualCount = 0;
  for (unsigned int i = 0; i < count; i++) {
    Protocol *protocol = list[i];
    // It is not uncommon for protocols to be added to classes like NSObject using categories. Here
    // we filter out any protocols that aren't translated from Java interfaces.
    if (IsJavaInterface(protocol, excludeNSCopying)) {
      buffer[actualCount++] = IOSClass_fromProtocol(list[i]);
    }
  }
  return [IOSObjectArray newArrayWithObjects:buffer
                                       count:actualCount
                                        type:IOSClass_class_()];
}

- (IOSObjectArray *)getTypeParameters {
  LibcoreReflectGenericSignatureParser *parser = NewParsedClassSignature(self);
  if (!parser) {
    return [IOSObjectArray arrayWithLength:0 type:JavaLangReflectTypeVariable_class_()];
  }
  IOSObjectArray *result = AUTORELEASE([parser->formalTypeParameters_ retain]);
  [parser release];
  return result;
}

- (id<JavaLangAnnotationAnnotation>)getAnnotationWithIOSClass:(IOSClass *)annotationClass {
  (void)nil_chk(annotationClass);
  IOSObjectArray *annotations = [self getAnnotations];
  jint n = annotations->size_;
  for (jint i = 0; i < n; i++) {
    id annotation = annotations->buffer_[i];
    if ([annotationClass isInstance:annotation]) {
      return annotation;
    }
  }
  return nil;
}

- (bool)isAnnotationPresentWithIOSClass:(IOSClass *)annotationClass {
  return [self getAnnotationWithIOSClass:annotationClass] != nil;
}

- (IOSObjectArray *)getAnnotations {
  NSMutableArray *array = AUTORELEASE([[NSMutableArray alloc] init]);
  IOSObjectArray *declared = [self getDeclaredAnnotations];
  for (jint i = 0; i < declared->size_; i++) {
    [array addObject:declared->buffer_[i]];
  }

  // Check for any inherited annotations.
  IOSClass *cls = [self getSuperclass];
  IOSClass *inheritedAnnotation = JavaLangAnnotationInherited_class_();
  while (cls) {
    IOSObjectArray *declared = [cls getDeclaredAnnotations];
    for (jint i = 0; i < declared->size_; i++) {
      id<JavaLangAnnotationAnnotation> annotation = declared->buffer_[i];
      IOSObjectArray *attributes = [[annotation java_getClass] getDeclaredAnnotations];
      for (jint j = 0; j < attributes->size_; j++) {
        id<JavaLangAnnotationAnnotation> attribute = attributes->buffer_[j];
        if (inheritedAnnotation == [attribute annotationType]) {
          [array addObject:annotation];
        }
      }
    }
    cls = [cls getSuperclass];
  }
  IOSObjectArray *result =
      [IOSObjectArray arrayWithNSArray:array type:JavaLangAnnotationAnnotation_class_()];
  return result;
}

- (IOSObjectArray *)getDeclaredAnnotations {
  const J2ObjcClassInfo *metadata = IOSClass_GetMetadataOrFail(self);
  id (*annotations)(void) = JrePtrAtIndex(metadata->ptrTable, metadata->annotationsIdx);
  if (annotations) {
    return annotations();
  }
  return [IOSObjectArray arrayWithLength:0 type:JavaLangAnnotationAnnotation_class_()];
}

- (id<JavaLangAnnotationAnnotation>)getDeclaredAnnotationWithIOSClass:(IOSClass *)annotationClass {
  return ((id<JavaLangAnnotationAnnotation>)
      JavaLangReflectAnnotatedElement_getDeclaredAnnotationWithIOSClass_(
          self, annotationClass));
}

- (IOSObjectArray *)getAnnotationsByTypeWithIOSClass:(IOSClass *)annotationClass {
  IOSObjectArray *annotations = LibcoreReflectAnnotatedElements_getDirectOrIndirectAnnotationsByTypeWithJavaLangReflectAnnotatedElement_withIOSClass_(
      self, annotationClass);
  if (annotations->size_ > 0) {
    return annotations;
  }

  if ([annotationClass getDeclaredAnnotationWithIOSClass:JavaLangAnnotationInherited_class_()]) {
    IOSClass *superClass = [self getSuperclass];
    if (superClass) {
      return [superClass getAnnotationsByTypeWithIOSClass:annotationClass];
    }
  }
  return annotations;
}

- (IOSObjectArray *)getDeclaredAnnotationsByTypeWithIOSClass:(IOSClass *)annotationClass {
  return LibcoreReflectAnnotatedElements_getDirectOrIndirectAnnotationsByTypeWithJavaLangReflectAnnotatedElement_withIOSClass_(
      self, annotationClass);
}

- (const J2ObjcClassInfo *)getMetadata {
  return metadata_;
}

- (NSString *)getTypeName {
  return JavaLangReflectType_getTypeName(self);
}

- (id)getPackage {
  NSString *packageName = JreClassPackageName(metadata_);
  if (packageName) {
    return AUTORELEASE([[JavaLangPackage alloc] initWithNSString:packageName
                                                    withNSString:nil
                                                    withNSString:nil
                                                    withNSString:nil
                                                    withNSString:nil
                                                    withNSString:nil
                                                    withNSString:nil
                                                  withJavaNetURL:nil
                                         withJavaLangClassLoader:nil]);
  }
  return nil;
}

- (NSString *)getPackageName {
  return JreClassPackageName(metadata_);
}

- (id)getClassLoader {
  return JavaLangClassLoader_getSystemClassLoader();
}

// Adds all the fields for a specified class to a specified dictionary.
static void GetFieldsFromClass(IOSClass *iosClass, NSMutableDictionary *fields, bool publicOnly) {
  const J2ObjcClassInfo *metadata = IOSClass_GetMetadataOrFail(iosClass);
  for (int i = 0; i < metadata->fieldCount; i++) {
    const J2ObjcFieldInfo *fieldInfo = &metadata->fields[i];
    if (publicOnly && (fieldInfo->modifiers & JavaLangReflectModifier_PUBLIC) == 0) {
      continue;
    }
    Ivar ivar = class_getInstanceVariable(iosClass.objcClass, fieldInfo->name);
    JavaLangReflectField *field = [JavaLangReflectField fieldWithIvar:ivar
                                                            withClass:iosClass
                                                         withMetadata:fieldInfo];
    NSString *name = [field getName];
    if (![fields valueForKey:name]) {
      [fields setObject:field forKey:name];
    }
  };
}

__attribute__((noreturn))
static void ThrowNoSuchFieldException(IOSClass *iosClass, NSString *fieldName) {
  NSMutableString *msg = [NSMutableString stringWithString:fieldName];
  [msg appendString:@". "];
  [msg appendString:JreMetadataToString(IOSClass_GetMetadataOrFail(iosClass))];
  @throw AUTORELEASE([[JavaLangNoSuchFieldException alloc] initWithNSString:msg]);
}

- (JavaLangReflectField *)getDeclaredField:(NSString *)name {
  (void)nil_chk(name);
  JavaLangReflectField *field = FindDeclaredField(self, name, false);
  if (field) {
    return field;
  }
  ThrowNoSuchFieldException(self, name);
}

- (JavaLangReflectField *)getField:(NSString *)name {
  (void)nil_chk(name);
  JavaLangReflectField *field = FindField(self, name, true);
  if (field) {
    return field;
  }
  ThrowNoSuchFieldException(self, name);
}

IOSObjectArray *copyFieldsToObjectArray(NSArray *fields) {
  jint count = (jint)[fields count];
  IOSObjectArray *results =
      [IOSObjectArray arrayWithLength:count type:JavaLangReflectField_class_()];
  for (jint i = 0; i < count; i++) {
    [results replaceObjectAtIndex:i withObject:[fields objectAtIndex:i]];
  }
  return results;
}

- (IOSObjectArray *)getDeclaredFields {
  NSMutableDictionary *fieldDictionary = [NSMutableDictionary dictionary];
  GetFieldsFromClass(self, fieldDictionary, false);
  return copyFieldsToObjectArray([fieldDictionary allValues]);
}

static void getAllFields(IOSClass *cls, NSMutableDictionary *fieldMap) {
  GetFieldsFromClass(cls, fieldMap, true);
  for (IOSClass *p in [cls getInterfacesInternal]) {
    getAllFields(p, fieldMap);
  }
  while ((cls = [cls getSuperclass])) {
    getAllFields(cls, fieldMap);
  }
}

- (IOSObjectArray *)getFields {
  NSMutableDictionary *fieldDictionary = [NSMutableDictionary dictionary];
  getAllFields(self, fieldDictionary);
  return copyFieldsToObjectArray([fieldDictionary allValues]);
}

- (JavaLangReflectMethod *)getEnclosingMethod {
  const J2ObjcClassInfo *metadata = IOSClass_GetMetadataOrFail(self);
  const char *enclosingMethod = JrePtrAtIndex(metadata->ptrTable, metadata->enclosingMethodIdx);
  if (!enclosingMethod) {
    return nil;
  }
  IOSClass *enclosingClass = JreClassForString(
      JrePtrAtIndex(metadata->ptrTable, metadata->enclosingClassIdx));
  return JreMethodForSelector(enclosingClass, sel_registerName(enclosingMethod));
}

- (JavaLangReflectConstructor *)getEnclosingConstructor {
  const J2ObjcClassInfo *metadata = IOSClass_GetMetadataOrFail(self);
  const char *enclosingMethod = JrePtrAtIndex(metadata->ptrTable, metadata->enclosingMethodIdx);
  if (!enclosingMethod) {
    return nil;
  }
  IOSClass *enclosingClass = JreClassForString(
      JrePtrAtIndex(metadata->ptrTable, metadata->enclosingClassIdx));
  return JreConstructorForSelector(enclosingClass, sel_registerName(enclosingMethod));
}


// Adds all the inner classes for a specified class to a specified dictionary.
static void GetInnerClasses(IOSClass *iosClass, NSMutableArray *classes, bool publicOnly,
                            bool includeInterfaces) {
  const J2ObjcClassInfo *metadata = iosClass->metadata_;
  if (metadata) {
    IOSObjectArray *innerClasses = JreParseClassList(
        JrePtrAtIndex(metadata->ptrTable, metadata->innerClassesIdx));
    for (jint i = 0; i < innerClasses->size_; i++) {
      IOSClass *c = IOSObjectArray_Get(innerClasses, i);
      if (![c isAnonymousClass] && ![c isSynthetic]) {
        if (publicOnly && ([c getModifiers] & JavaLangReflectModifier_PUBLIC) == 0) {
          continue;
        }
        if ([c isInterface] && !includeInterfaces) {
          continue;
        }
        [classes addObject:c];
      }
    }
  }
}

- (IOSObjectArray *)getClasses {
  NSMutableArray *innerClasses = [[NSMutableArray alloc] init];
  IOSClass *cls = self;
  GetInnerClasses(cls, innerClasses, true, true);
  while ((cls = [cls getSuperclass])) {
    // Class.getClasses() shouldn't include interfaces from superclasses.
    GetInnerClasses(cls, innerClasses, true, false);
  }
  IOSObjectArray *result = [IOSObjectArray arrayWithNSArray:innerClasses
                                                       type:IOSClass_class_()];
  [innerClasses release];
  return result;
}

- (IOSObjectArray *)getDeclaredClasses {
  NSMutableArray *declaredClasses = [[NSMutableArray alloc] init];
  GetInnerClasses(self, declaredClasses, false, true);
  IOSObjectArray *result = [IOSObjectArray arrayWithNSArray:declaredClasses
                                                       type:IOSClass_class_()];
  [declaredClasses release];
  return result;
}

- (bool)isAnonymousClass {
  return false;
}

- (bool)desiredAssertionStatus {
  return false;
}

static IOSObjectArray *GetEnumConstants(IOSClass *cls) {
  return [cls isEnum] ? JavaLangEnum_getSharedConstantsWithIOSClass_(cls) : nil;
}

- (IOSObjectArray *)getEnumConstants {
  return [GetEnumConstants(self) java_clone];
}

- (IOSObjectArray *)getRecordComponents {
  if (![self isRecord]) {
    return nil;
  }
  // Return record components in declaration order, which is how they're stored in metadata.
  const J2ObjcClassInfo *metadata = IOSClass_GetMetadataOrFail(self);
  uint16_t fieldCount = metadata->fieldCount;
  NSMutableArray *componentFields = [[NSMutableArray alloc] initWithCapacity:fieldCount];
  for (uint16_t i = 0; i < fieldCount; i++) {
    const J2ObjcFieldInfo *fieldInfo = &metadata->fields[i];
    if (fieldInfo->modifiers == (JavaLangReflectModifier_PRIVATE | JavaLangReflectModifier_FINAL)) {
      [componentFields addObject:[self getDeclaredField:
          [NSString stringWithUTF8String:fieldInfo->name]]];
    }
  }

  uint16_t count = (jint)[componentFields count];
  IOSObjectArray *result =
      [IOSObjectArray arrayWithLength:count type:JavaLangReflectRecordComponent_class_()];
  for (uint16_t i = 0; i < count; i++) {
    JavaLangReflectField *field = [componentFields objectAtIndex:i];
    NSString *name = [field getName];
    JavaLangReflectMethod *accessor = [self getMethod:name parameterTypes:nil];
    JavaLangReflectRecordComponent *comp = 
          [[JavaLangReflectRecordComponent alloc] initWithIOSClass:self
                                          withJavaLangReflectField:field
                                         withJavaLangReflectMethod:accessor];
    [result replaceObjectAtIndex:i withObject:comp];
    [comp release];
  }
  [componentFields release];
  return result;
}

// Package private method. In OpenJDK it differentiated from the above because
// a single constants array is cached and then cloned by getEnumConstants().
// That's not necessary here, since the Enum.getSharedConstants() function
// creates a new array.
- (IOSObjectArray *)getEnumConstantsShared {
  return GetEnumConstants(self);
}

- (Class)objcArrayClass {
  return [IOSObjectArray class];
}

- (size_t)getSizeof {
  return sizeof(id);
}

NSString *resolveResourceName(IOSClass *cls, NSString *resourceName) {
  if (!resourceName || [resourceName length] == 0) {
    return resourceName;
  }
  if ([resourceName characterAtIndex:0] == '/') {
    return resourceName;
  }
  NSString *relativePath = [[[cls getPackage] getName] stringByReplacingOccurrencesOfString:@"."
                                                                                 withString:@"/"];
  return [NSString stringWithFormat:@"/%@/%@", relativePath, resourceName];
}

- (JavaNetURL *)getResource:(NSString *)name {
  return [[self getClassLoader] getResourceWithNSString:resolveResourceName(self, name)];
}

- (JavaIoInputStream *)getResourceAsStream:(NSString *)name {
  return [[self getClassLoader] getResourceAsStreamWithNSString:resolveResourceName(self, name)];
}

// These java.security methods don't have an iOS equivalent, so always return nil.
- (id)getProtectionDomain {
  return nil;
}

- (id)getSigners {
  return nil;
}


- (id)__boxValue:(J2ObjcRawValue *)rawValue {
  return (id)rawValue->asId;
}

- (bool)__unboxValue:(id)value toRawValue:(J2ObjcRawValue *)rawValue {
  rawValue->asId = value;
  return true;
}

- (void)__readRawValue:(J2ObjcRawValue *)rawValue fromAddress:(const void *)addr {
  rawValue->asId = *(id *)addr;
}

- (void)__writeRawValue:(J2ObjcRawValue *)rawValue toAddress:(const void *)addr {
  *(id *)addr = (id)rawValue->asId;
}

- (bool)__convertRawValue:(J2ObjcRawValue *)rawValue toType:(IOSClass *)type {
  // No conversion necessary if both types are ids.
  return ![type isPrimitive];
}

// Implementing NSCopying allows IOSClass objects to be used as keys in the
// class cache.
- (instancetype)copyWithZone:(NSZone *)zone {
  return self;
}

- (IOSClass *)java_getClass {
  return IOSClass_class_();
}

static bool IsStringType(Class cls) {
  // We can't trigger class initialization because that might recursively enter
  // FetchClass and result in deadlock within the FastPointerLookup. Therefore,
  // we can't use [cls isSubclassOfClass:[NSString class]].
  Class stringCls = [NSString class];
  while (cls) {
    if (cls == stringCls) {
      return true;
    }
    cls = class_getSuperclass(cls);
  }
  return false;
}

static void *ClassLookup(void *clsPtr) {
  Class cls = (Class)clsPtr;
  if (IsStringType(cls)) {
    // NSString is implemented by several subclasses.
    // Thread safety is guaranteed by the FastPointerLookup that calls this.
    static IOSClass *stringClass;
    if (!stringClass) {
      stringClass = [[IOSConcreteClass alloc] initWithClass:[NSString class]];
    }
    return stringClass;
  }
  IOSClass *result = [[IOSConcreteClass alloc] initWithClass:cls];
  return result;
}

static FastPointerLookup_t classLookup = FAST_POINTER_LOOKUP_INIT(&ClassLookup);

IOSClass *IOSClass_fromClass(Class cls) {
  // We get deadlock if IOSClass is not initialized before entering the fast
  // lookup because +initialize makes calls into IOSClass_fromClass().
  IOSClass_initialize();
  return (IOSClass *)FastPointerLookup(&classLookup, cls);
}

IOSClass *IOSClass_NewProxyClass(Class cls) {
  IOSClass *result = [[IOSProxyClass alloc] initWithClass:cls];
  if (!FastPointerLookupAddMapping(&classLookup, cls, result)) {
    // This function should only be called by java.lang.reflect.Proxy
    // immediately after creating a new proxy class.
    @throw create_JavaLangAssertionError_init();
  }
  return result;
}

static void *ProtocolLookup(void *protocol) {
  return [[IOSProtocolClass alloc] initWithProtocol:(Protocol *)protocol];
}

static FastPointerLookup_t protocolLookup = FAST_POINTER_LOOKUP_INIT(&ProtocolLookup);

IOSClass *IOSClass_fromProtocol(Protocol *protocol) {
  return (IOSClass *)FastPointerLookup(&protocolLookup, protocol);
}

static void *ArrayLookup(void *componentType) {
  return [[IOSArrayClass alloc] initWithComponentType:(IOSClass *)componentType];
}

static FastPointerLookup_t arrayLookup = FAST_POINTER_LOOKUP_INIT(&ArrayLookup);

IOSClass *IOSClass_arrayOf(IOSClass *componentType) {
  return (IOSClass *)FastPointerLookup(&arrayLookup, componentType);
}

IOSClass *IOSClass_arrayType(IOSClass *componentType, jint dimensions) {
  IOSClass *result = (IOSClass *)FastPointerLookup(&arrayLookup, componentType);
  while (--dimensions > 0) {
    result = (IOSClass *)FastPointerLookup(&arrayLookup, result);
  }
  return result;
}

+ (void)initialize {
  if (self == [IOSClass class]) {
    IOSClass_byteClass = [[IOSPrimitiveClass alloc] initWithName:@"byte" type:@"B"];
    IOSClass_charClass = [[IOSPrimitiveClass alloc] initWithName:@"char" type:@"C"];
    IOSClass_doubleClass = [[IOSPrimitiveClass alloc] initWithName:@"double" type:@"D"];
    IOSClass_floatClass = [[IOSPrimitiveClass alloc] initWithName:@"float" type:@"F"];
    IOSClass_intClass = [[IOSPrimitiveClass alloc] initWithName:@"int" type:@"I"];
    IOSClass_longClass = [[IOSPrimitiveClass alloc] initWithName:@"long" type:@"J"];
    IOSClass_shortClass = [[IOSPrimitiveClass alloc] initWithName:@"short" type:@"S"];
    IOSClass_booleanClass = [[IOSPrimitiveClass alloc] initWithName:@"boolean" type:@"Z"];
    IOSClass_voidClass = [[IOSPrimitiveClass alloc] initWithName:@"void" type:@"V"];

    IOSClass_objectClass = IOSClass_fromClass([NSObject class]);

    IOSClass_emptyClassArray = [IOSObjectArray newArrayWithLength:0 type:IOSClass_class_()];

    // Load and initialize JRE categories, using their dummy classes.
    [JreObjectCategoryDummy class];
    [JreStringCategoryDummy class];
    [JreNumberCategoryDummy class];
    [NSCopying class];

    // Verify that these categories successfully loaded.
    if ([[NSObject class] instanceMethodSignatureForSelector:@selector(compareToWithId:)] == NULL ||
        [[NSString class] instanceMethodSignatureForSelector:@selector(java_trim)] == NULL ||
        ![NSNumber conformsToProtocol:@protocol(JavaIoSerializable)]) {
      [NSException raise:@"J2ObjCLinkError"
                  format:@"Your project is not configured to load categories from the JRE "
                          "emulation library. Try adding the -force_load linker flag."];
    }

    J2OBJC_SET_INITIALIZED(IOSClass)
  }
}

// Generated by running the translator over the java.lang.Class stub file.
+ (const J2ObjcClassInfo *)__metadata {
  static J2ObjcMethodInfo methods[] = {
    { NULL, NULL, 0x2, -1, -1, -1, -1, -1, -1 },
    { NULL, "LIOSClass;", 0x9, 0, 1, 2, 3, -1, -1 },
    { NULL, "LIOSClass;", 0x9, 0, 4, 2, 5, -1, -1 },
    { NULL, "LIOSClass;", 0x1, 6, 7, -1, 8, -1, -1 },
    { NULL, "LNSObject;", 0x1, 9, 10, -1, 11, -1, -1 },
    { NULL, "Z", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "LJavaLangAnnotationAnnotation;", 0x1, 12, 7, -1, 13, -1, -1 },
    { NULL, "[LJavaLangAnnotationAnnotation;", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "LNSString;", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "[LIOSClass;", 0x1, -1, -1, -1, 14, -1, -1 },
    { NULL, "LJavaLangClassLoader;", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "LIOSClass;", 0x1, -1, -1, -1, 15, -1, -1 },
    { NULL, "LJavaLangReflectConstructor;", 0x81, 16, 17, 18, 19, -1, -1 },
    { NULL, "[LJavaLangReflectConstructor;", 0x1, -1, -1, 20, 21, -1, -1 },
    { NULL, "[LJavaLangAnnotationAnnotation;", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "[LIOSClass;", 0x1, -1, -1, -1, 14, -1, -1 },
    { NULL, "LJavaLangReflectConstructor;", 0x81, 22, 17, 18, 19, -1, -1 },
    { NULL, "[LJavaLangReflectConstructor;", 0x1, -1, -1, 20, 21, -1, -1 },
    { NULL, "LJavaLangReflectField;", 0x1, 23, 1, 24, -1, -1, -1 },
    { NULL, "[LJavaLangReflectField;", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "[LJavaLangReflectRecordComponent;", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "LJavaLangReflectMethod;", 0x81, 25, 26, 18, 27, -1, -1 },
    { NULL, "[LJavaLangReflectMethod;", 0x1, -1, -1, 20, -1, -1, -1 },
    { NULL, "LIOSClass;", 0x1, -1, -1, -1, 15, -1, -1 },
    { NULL, "LIOSClass;", 0x1, -1, -1, -1, 15, -1, -1 },
    { NULL, "LJavaLangReflectConstructor;", 0x1, -1, -1, -1, 28, -1, -1 },
    { NULL, "LJavaLangReflectMethod;", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "[LNSObject;", 0x1, -1, -1, -1, 29, -1, -1 },
    { NULL, "[LNSObject;", 0x0, -1, -1, -1, 29, -1, -1 },
    { NULL, "LJavaLangReflectField;", 0x1, 30, 1, 24, -1, -1, -1 },
    { NULL, "[LJavaLangReflectField;", 0x1, -1, -1, 20, -1, -1, -1 },
    { NULL, "[LJavaLangReflectType;", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "LJavaLangReflectType;", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "[LIOSClass;", 0x1, -1, -1, -1, 14, -1, -1 },
    { NULL, "LJavaLangReflectMethod;", 0x81, 31, 26, 18, 27, -1, -1 },
    { NULL, "[LJavaLangReflectMethod;", 0x1, -1, -1, 20, -1, -1, -1 },
    { NULL, "I", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "LNSString;", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "LJavaLangPackage;", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "LNSString;", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "LJavaSecurityProtectionDomain;", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "LJavaNetURL;", 0x1, 32, 1, -1, -1, -1, -1 },
    { NULL, "LJavaIoInputStream;", 0x1, 33, 1, -1, -1, -1, -1 },
    { NULL, "[LNSObject;", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "LNSString;", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "LIOSClass;", 0x1, -1, -1, -1, 34, -1, -1 },
    { NULL, "[LJavaLangReflectTypeVariable;", 0x1, -1, -1, -1, 35, -1, -1 },
    { NULL, "Z", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "Z", 0x1, 36, 7, -1, 37, -1, -1 },
    { NULL, "Z", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "Z", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "Z", 0x1, 38, 7, -1, 39, -1, -1 },
    { NULL, "Z", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "Z", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "Z", 0x1, 40, 10, -1, -1, -1, -1 },
    { NULL, "Z", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "Z", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "Z", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "Z", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "Z", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "LNSObject;", 0x1, -1, -1, 41, 42, -1, -1 },
    { NULL, "LNSString;", 0x1, 43, -1, -1, -1, -1, -1 },
    { NULL, "[LJavaLangAnnotationAnnotation;", 0x1, 44, 7, -1, 45, -1, -1 },
    { NULL, "[LJavaLangAnnotationAnnotation;", 0x1, 46, 7, -1, 45, -1, -1 },
    { NULL, "LJavaLangAnnotationAnnotation;", 0x1, 47, 7, -1, 13, -1, -1 },
    { NULL, "LNSString;", 0x1, -1, -1, -1, -1, -1, -1 },
    { NULL, "LNSString;", 0x1, -1, -1, -1, -1, -1, -1 },
  };
  #pragma clang diagnostic push
  #pragma clang diagnostic ignored "-Wobjc-multiple-method-names"
  #pragma clang diagnostic ignored "-Wundeclared-selector"
  methods[0].selector = @selector(init);
  methods[1].selector = @selector(forName:);
  methods[2].selector = @selector(forName:initialize:classLoader:);
  methods[3].selector = @selector(asSubclass:);
  methods[4].selector = @selector(cast:);
  methods[5].selector = @selector(desiredAssertionStatus);
  methods[6].selector = @selector(getAnnotationWithIOSClass:);
  methods[7].selector = @selector(getAnnotations);
  methods[8].selector = @selector(getCanonicalName);
  methods[9].selector = @selector(getClasses);
  methods[10].selector = @selector(getClassLoader);
  methods[11].selector = @selector(getComponentType);
  methods[12].selector = @selector(getConstructor:);
  methods[13].selector = @selector(getConstructors);
  methods[14].selector = @selector(getDeclaredAnnotations);
  methods[15].selector = @selector(getDeclaredClasses);
  methods[16].selector = @selector(getDeclaredConstructor:);
  methods[17].selector = @selector(getDeclaredConstructors);
  methods[18].selector = @selector(getDeclaredField:);
  methods[19].selector = @selector(getDeclaredFields);
  methods[20].selector = @selector(getRecordComponents);
  methods[21].selector = @selector(getDeclaredMethod:parameterTypes:);
  methods[22].selector = @selector(getDeclaredMethods);
  methods[23].selector = @selector(getDeclaringClass);
  methods[24].selector = @selector(getEnclosingClass);
  methods[25].selector = @selector(getEnclosingConstructor);
  methods[26].selector = @selector(getEnclosingMethod);
  methods[27].selector = @selector(getEnumConstants);
  methods[28].selector = @selector(getEnumConstantsShared);
  methods[29].selector = @selector(getField:);
  methods[30].selector = @selector(getFields);
  methods[31].selector = @selector(getGenericInterfaces);
  methods[32].selector = @selector(getGenericSuperclass);
  methods[33].selector = @selector(getInterfaces);
  methods[34].selector = @selector(getMethod:parameterTypes:);
  methods[35].selector = @selector(getMethods);
  methods[36].selector = @selector(getModifiers);
  methods[37].selector = @selector(getName);
  methods[38].selector = @selector(getPackage);
  methods[39].selector = @selector(getPackageName);
  methods[40].selector = @selector(getProtectionDomain);
  methods[41].selector = @selector(getResource:);
  methods[42].selector = @selector(getResourceAsStream:);
  methods[43].selector = @selector(getSigners);
  methods[44].selector = @selector(getSimpleName);
  methods[45].selector = @selector(getSuperclass);
  methods[46].selector = @selector(getTypeParameters);
  methods[47].selector = @selector(isAnnotation);
  methods[48].selector = @selector(isAnnotationPresentWithIOSClass:);
  methods[49].selector = @selector(isAnonymousClass);
  methods[50].selector = @selector(isArray);
  methods[51].selector = @selector(isAssignableFrom:);
  methods[52].selector = @selector(isEnum);
  methods[53].selector = @selector(isRecord);
  methods[54].selector = @selector(isInstance:);
  methods[55].selector = @selector(isInterface);
  methods[56].selector = @selector(isLocalClass);
  methods[57].selector = @selector(isMemberClass);
  methods[58].selector = @selector(isPrimitive);
  methods[59].selector = @selector(isSynthetic);
  methods[60].selector = @selector(newInstance);
  methods[61].selector = @selector(description);
  methods[62].selector = @selector(getDeclaredAnnotationsByTypeWithIOSClass:);
  methods[63].selector = @selector(getAnnotationsByTypeWithIOSClass:);
  methods[64].selector = @selector(getDeclaredAnnotationWithIOSClass:);
  methods[65].selector = @selector(getTypeName);
  methods[66].selector = @selector(toGenericString);
  #pragma clang diagnostic pop
  static const J2ObjcFieldInfo fields[] = {
    { "serialVersionUID", "J", .constantValue.asLong = IOSClass_serialVersionUID, 0x1a, -1, -1, -1,
      -1 },
  };
  static const void *ptrTable[] = {
    "forName", "LNSString;", "LJavaLangClassNotFoundException;",
    "(Ljava/lang/String;)Ljava/lang/Class<*>;", "LNSString;ZLJavaLangClassLoader;",
    "(Ljava/lang/String;ZLjava/lang/ClassLoader;)Ljava/lang/Class<*>;", "asSubclass", "LIOSClass;",
    "<U:Ljava/lang/Object;>(Ljava/lang/Class<TU;>;)Ljava/lang/Class<+TU;>;", "cast", "LNSObject;",
    "(Ljava/lang/Object;)TT;", "getAnnotation",
    "<A::Ljava/lang/annotation/Annotation;>(Ljava/lang/Class<TA;>;)TA;", "()[Ljava/lang/Class<*>;",
    "()Ljava/lang/Class<*>;", "getConstructor", "[LIOSClass;",
    "LJavaLangNoSuchMethodException;LJavaLangSecurityException;",
    "([Ljava/lang/Class<*>;)Ljava/lang/reflect/Constructor<TT;>;", "LJavaLangSecurityException;",
    "()[Ljava/lang/reflect/Constructor<*>;", "getDeclaredConstructor", "getDeclaredField",
    "LJavaLangNoSuchFieldException;", "getDeclaredMethod", "LNSString;[LIOSClass;",
    "(Ljava/lang/String;[Ljava/lang/Class<*>;)Ljava/lang/reflect/Method;",
    "()Ljava/lang/reflect/Constructor<*>;", "()[TT;", "getField", "getMethod", "getResource",
    "getResourceAsStream", "()Ljava/lang/Class<-TT;>;",
    "()[Ljava/lang/reflect/TypeVariable<Ljava/lang/Class<TT;>;>;", "isAnnotationPresent",
    "(Ljava/lang/Class<+Ljava/lang/annotation/Annotation;>;)Z", "isAssignableFrom",
    "(Ljava/lang/Class<*>;)Z", "isInstance",
    "LJavaLangInstantiationException;LJavaLangIllegalAccessException;", "()TT;", "toString",
    "getDeclaredAnnotationsByType",
    "<A::Ljava/lang/annotation/Annotation;>(Ljava/lang/Class<TA;>;)[TA;", "getAnnotationsByType",
    "getDeclaredAnnotation",
    "<T:Ljava/lang/Object;>Ljava/lang/Object;Ljava/io/Serializable;"
    "Ljava/lang/reflect/GenericDeclaration;Ljava/lang/reflect/Type;"
    "Ljava/lang/reflect/AnnotatedElement;" };
  static const J2ObjcClassInfo _IOSClass = {
    "Class", "java.lang", ptrTable, methods, fields, 7, 0x11, 67, 1, -1, -1, -1, 48, -1 };
  return &_IOSClass;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"
- (void)dealloc {
  @throw create_JavaLangAssertionError_initWithId_(
      [NSString stringWithFormat:@"Unexpected IOSClass dealloc: %@", [self getName]]);
}
#pragma clang diagnostic pop

@end

J2OBJC_CLASS_TYPE_LITERAL_SOURCE(IOSClass)

J2OBJC_NAME_MAPPING(IOSClass, "java.lang.Class", "IOSClass")

@implementation PackagePrefixEntry

- (instancetype)initWithNSString:(NSString *)key
                    withNSString:(NSString *)value {
  if ((self = [super init])) {
    key_ = [key retain];
    value_ = [value retain];
  }
  return self;
}

- (NSString *)key {
  return key_;
}

- (NSString *)value {
  return value_;
}

#if !__has_feature(objc_arc)
- (void)dealloc {
  RELEASE_(key_);
  RELEASE_(value_);
  [super dealloc];
}
#endif

@end

@implementation PackagePrefixLoader

- (void)load__WithNSString:(NSString *)key withNSString:(NSString *)value {
  PackagePrefixEntry *entry = [[PackagePrefixEntry alloc] initWithNSString:key withNSString:value];
  [nil_chk(prefixMapping) addWithId:entry];
  [entry release];
}

@end
