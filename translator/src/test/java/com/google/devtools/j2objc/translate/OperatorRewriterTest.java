/*
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.google.devtools.j2objc.translate;

import com.google.devtools.j2objc.GenerationTest;
import com.google.devtools.j2objc.Options.MemoryManagementOption;
import com.google.devtools.j2objc.ast.Statement;
import java.io.IOException;
import java.util.List;

/**
 * Unit tests for {@link OperatorRewriter}.
 *
 * @author Keith Stanger
 */
public class OperatorRewriterTest extends GenerationTest {

  public void testSetFieldOnResultOfExpression() throws IOException {
    String translation =
        translateSourceFile(
            "class Test { String s; static Test getTest() { return null; } "
                + "void test(boolean b) { (b ? new Test() : getTest()).s = \"foo\"; } }",
            "Test",
            "Test.m");
    assertTranslation(translation,
        "JreStrongAssign(&(b ? create_Test_init() : Test_getTest())->s_, @\"foo\");");
  }

  public void testSetFieldOnResultOfExpressionStrictFieldAssign() throws IOException {
    options.setStrictFieldAssign(true);
    String translation =
        translateSourceFile(
            "class Test { String s; static Test getTest() { return null; } "
                + "void test(boolean b) { (b ? new Test() : getTest()).s = \"foo\"; } }",
            "Test",
            "Test.m");
    assertTranslation(
        translation,
        "JreStrictFieldStrongAssign(&(b ? create_Test_init() : Test_getTest())->s_, @\"foo\");");
  }

  public void testDivisionOperator() {
    String source = "short s = 0; int i = 3 / s; long l = 7L / s; double d = 9.0 / s;";
    List<Statement> stmts = translateStatements(source);
    assertEquals(4, stmts.size());
    assertEquals("int32_t i = JreIntDiv(3, s);", generateStatement(stmts.get(1)));
    assertEquals("int64_t l = JreLongDiv(7LL, s);", generateStatement(stmts.get(2)));
    assertEquals("double d = 9.0 / s;", generateStatement(stmts.get(3)));
  }

  public void testModuloOperator() {
    String source = "short s = 0; int i = 3 % s; long l = 7L % s; double d = 9.0 % s;";
    List<Statement> stmts = translateStatements(source);
    assertEquals(4, stmts.size());
    assertEquals("int32_t i = JreIntMod(3, s);", generateStatement(stmts.get(1)));
    assertEquals("int64_t l = JreLongMod(7LL, s);", generateStatement(stmts.get(2)));
    assertEquals("double d = fmod(9.0, s);", generateStatement(stmts.get(3)));
  }

  public void testModAssignOperator() {
    String source = "float a = 4.2f; a %= 2.1f; double b = 5.6; b %= 1.2; byte c = 3; c %= 2.3; "
        + "short d = 4; d %= 3.4; int e = 5; e %= 4.5; long f = 6; f %= 5.6; char g = 'a'; "
        + "g %= 6.7;";
    List<Statement> stmts = translateStatements(source);
    assertEquals(14, stmts.size());
    assertEquals("JreModAssignFloatF(&a, 2.1f);", generateStatement(stmts.get(1)));
    assertEquals("JreModAssignDoubleD(&b, 1.2);", generateStatement(stmts.get(3)));
    assertEquals("JreModAssignByteD(&c, 2.3);", generateStatement(stmts.get(5)));
    assertEquals("JreModAssignShortD(&d, 3.4);", generateStatement(stmts.get(7)));
    assertEquals("JreModAssignIntD(&e, 4.5);", generateStatement(stmts.get(9)));
    assertEquals("JreModAssignLongD(&f, 5.6);", generateStatement(stmts.get(11)));
    assertEquals("JreModAssignCharD(&g, 6.7);", generateStatement(stmts.get(13)));
  }

  public void testDoubleModulo() throws IOException {
    String translation = translateSourceFile(
      "public class A { "
      + "  double doubleMod(double one, double two) { return one % two; }"
      + "  float floatMod(float three, float four) { return three % four; }}",
      "A", "A.m");
    assertTranslation(translation, "return fmod(one, two);");
    assertTranslation(translation, "return fmodf(three, four);");
  }

  public void testLShift32WithExtendedOperands() {
    String source = "int a; a = 1 << 2; a = 1 << 2 << 3; a = 1 << 2 << 3 << 4;";
    List<Statement> stmts = translateStatements(source);
    assertEquals(4, stmts.size());
    assertEquals("a = JreLShift32(1, 2);", generateStatement(stmts.get(1)));
    assertEquals("a = JreLShift32(JreLShift32(1, 2), 3);", generateStatement(stmts.get(2)));
    assertEquals("a = JreLShift32(JreLShift32(JreLShift32(1, 2), 3), 4);",
                 generateStatement(stmts.get(3)));
  }

  public void testURShift64WithExtendedOperands() {
    String source = "long a; a = 65535L >>> 2; a = 65535L >>> 2 >>> 3; "
        + "a = 65535L >>> 2 >>> 3 >>> 4;";
    List<Statement> stmts = translateStatements(source);
    assertEquals(4, stmts.size());
    assertEquals("a = JreURShift64(65535LL, 2);", generateStatement(stmts.get(1)));
    assertEquals("a = JreURShift64(JreURShift64(65535LL, 2), 3);", generateStatement(stmts.get(2)));
    assertEquals("a = JreURShift64(JreURShift64(JreURShift64(65535LL, 2), 3), 4);",
            generateStatement(stmts.get(3)));
  }

  public void testStringAppendOperator() throws IOException {
    String translation = translateSourceFile(
        "import com.google.j2objc.annotations.Weak;"
        + " class Test { String ss; @Weak String ws; String[] as;"
        + " void test() { ss += \"foo\"; ws += \"bar\"; as[0] += \"baz\"; } }",
        "Test", "Test.m");
    assertTranslatedLines(translation,
        "JreStrAppendStrong(&ss_, \"$\", @\"foo\");",
        "JreStrAppend(&ws_, \"$\", @\"bar\");",
        "JreStrAppendArray(IOSObjectArray_GetRef(nil_chk(as_), 0), \"$\", @\"baz\");");
  }

  public void testStringAppendOperatorStrictField() throws IOException {
    options.setStrictFieldAssign(true);
    options.setStrictFieldLoad(true);

    String translation =
        translateSourceFile(
            "import com.google.j2objc.annotations.Weak;"
                + " class Test { String ss; @Weak String ws; String[] as;"
                + " void test() { ss += \"foo\"; ws += \"bar\"; as[0] += \"baz\"; } }",
            "Test",
            "Test.m");
    assertTranslatedLines(
        translation,
        "JreStrAppendStrictFieldStrong(&ss_, \"$\", @\"foo\");",
        "JreStrAppend(&ws_, \"$\", @\"bar\");",
        "JreStrAppendArray(IOSObjectArray_GetRef(nil_chk(JreStrictFieldStrongLoad(&as_)), 0),"
            + " \"$\", @\"baz\");");
  }

  public void testParenthesizedLeftHandSide() throws IOException {
    String translation =
        translateSourceFile(
            "class Test { String s; void test(String s2) { (s) = s2; } }", "Test", "Test.m");
    assertTranslation(translation, "JreStrongAssign(&(s_), s2);");
  }

  public void testParenthesizedLeftHandSideStrictField() throws IOException {
    options.setStrictFieldAssign(true);
    options.setStrictFieldLoad(true);
    String translation =
        translateSourceFile(
            "class Test { String s; void test(String s2) { (s) = s2; } }", "Test", "Test.m");
    assertTranslation(translation, "JreStrictFieldStrongAssign(&(s_), s2);");
  }

  public void testVolatileLoadAndAssign() throws IOException {
    String translation = translateSourceFile(
        "import com.google.j2objc.annotations.Weak;"
        + " class Test { volatile int i; static volatile int si; volatile String s;"
        + " static volatile String vs; @Weak volatile String ws;"
        + " void test() { int li = i; i = 2; li = si; si = 3; String ls = s; s = \"foo\";"
        + " ls = vs; vs = \"foo\"; ls = ws; ws = \"foo\"; } }", "Test", "Test.m");
    assertTranslatedLines(translation,
        "int32_t li = JreLoadVolatileInt(&i_);",
        "JreAssignVolatileInt(&i_, 2);",
        "li = JreLoadVolatileInt(&Test_si);",
        "JreAssignVolatileInt(&Test_si, 3);",
        "NSString *ls = JreLoadVolatileId(&s_);",
        "JreVolatileStrongAssign(&s_, @\"foo\");",
        "ls = JreLoadVolatileId(&Test_vs);",
        "JreVolatileStrongAssign(&Test_vs, @\"foo\");",
        "ls = JreLoadVolatileId(&ws_);",
        "JreAssignVolatileId(&ws_, @\"foo\");");
  }

  public void testStrictFieldLoadAndAssign() throws IOException {
    options.setStrictFieldAssign(true);
    options.setStrictFieldLoad(true);
    String translation =
        translateSourceFile(
            "import com.google.j2objc.annotations.Weak;"
                + " class Test { String s; static String ss; @Weak String ws;"
                + " void test() { String ls = s; s = \"foo\";"
                + " ls = ss; ss = \"foo\"; ls = ws; ws = \"foo\"; } }",
            "Test",
            "Test.m");
    assertTranslatedLines(
        translation,
        "NSString *ls = JreStrictFieldStrongLoad(&s_);",
        "JreStrictFieldStrongAssign(&s_, @\"foo\");",
        "ls = JreStrictFieldStrongLoad(&Test_ss);",
        "JreStrictFieldStrongAssign(&Test_ss, @\"foo\");",
        "ls = ws_;",
        "ws_ = @\"foo\";");
  }

  public void testPromotionTypesForCompundAssign() throws IOException {
    String translation = translateSourceFile(
        "class Test { volatile short s; int i; void test() {"
        + " s += 1; s -= 2l; s *= 3.0f; s /= 4.0; s %= 5l; i %= 6.0; } }", "Test", "Test.m");
    assertTranslatedLines(translation,
        "JrePlusAssignVolatileShortI(&s_, 1);",
        "JreMinusAssignVolatileShortJ(&s_, 2l);",
        "JreTimesAssignVolatileShortF(&s_, 3.0f);",
        "JreDivideAssignVolatileShortD(&s_, 4.0);",
        "JreModAssignVolatileShortJ(&s_, 5l);",
        "JreModAssignIntD(&i_, 6.0);");
  }

  public void testStringAppendLocalVariableARC() throws IOException {
    options.setMemoryManagementOption(MemoryManagementOption.ARC);
    String translation = translateSourceFile(
        "class Test { void test() { String str = \"foo\"; str += \"bar\"; } }", "Test", "Test.m");
    // Local variables in ARC have strong semantics.
    assertTranslation(translation, "JreStrAppendStrong(&str, \"$\", @\"bar\")");
  }

  public void testStringAppendInfixExpression() throws IOException {
    String translation = translateSourceFile(
        "class Test { void test(int x, int y) { "
        + "String str = \"foo\"; str += x + y; } }", "Test", "Test.m");
    assertTranslation(translation, "JreStrAppend(&str, \"I\", x + y);");
    translation = translateSourceFile(
        "class Test { void test(int x) { "
        + "String str = \"foo\"; str += \"bar\" + x; } }", "Test", "Test.m");
    assertTranslation(translation, "JreStrAppend(&str, \"$I\", @\"bar\", x);");
  }

  public void testRetainedWithAnnotation() throws IOException {
    String translation = translateSourceFile(
        "import com.google.j2objc.annotations.RetainedWith;"
        + "class Test { @RetainedWith Object rwo; @RetainedWith volatile Object rwvo;"
        + "Test getTest() { return new Test(); }"
        + "void test() { rwo = new Object(); rwvo = new Object(); }"
        + "void test2() { getTest().rwo = new Object(); } }", "Test", "Test.m");
    assertTranslation(translation, "JreRetainedWithAssign(self, &rwo_, create_NSObject_init());");
    assertTranslation(translation,
        "JreVolatileRetainedWithAssign(self, &rwvo_, create_NSObject_init());");
    assertTranslatedLines(translation,
        // The getTest() call must be extracted so that it can be passed as the parent ref without
        // duplicating the expression.
        "t *__rw$0;",
        "((void) (__rw$0 = nil_chk([self getTest])), "
          + "JreRetainedWithAssign(__rw$0, &__rw$0->rwo_, create_NSObject_init()));");
    // Test the dealloc calls too.
    assertTranslation(translation, "JreRetainedWithRelease(self, rwo_);");
    assertTranslation(translation, "JreVolatileRetainedWithRelease(self, &rwvo_);");
  }

  public void testRetainedWithAnnotationStrictField() throws IOException {
    options.setStrictFieldAssign(true);
    options.setStrictFieldLoad(true);
    String translation =
        translateSourceFile(
            "import com.google.j2objc.annotations.RetainedWith;"
                + "class Test { @RetainedWith Object rwo; @RetainedWith volatile Object rwvo;"
                + "Test getTest() { return new Test(); }"
                + "void test() { rwo = new Object(); rwvo = new Object(); }"
                + "void test2() { getTest().rwo = new Object(); } }",
            "Test",
            "Test.m");
    assertTranslation(translation, "JreRetainedWithAssign(self, &rwo_, create_NSObject_init());");
    assertTranslation(
        translation, "JreVolatileRetainedWithAssign(self, &rwvo_, create_NSObject_init());");
    assertTranslatedLines(
        translation,
        // The getTest() call must be extracted so that it can be passed as the parent ref without
        // duplicating the expression.
        "t *__rw$0;",
        "((void) (__rw$0 = nil_chk([self getTest])), "
            + "JreRetainedWithAssign(__rw$0, &__rw$0->rwo_, create_NSObject_init()));");
    // Test the dealloc calls too.
    assertTranslation(translation, "JreStrictFieldRetainedWithRelease(self, &rwo_);");
    assertTranslation(translation, "JreVolatileRetainedWithRelease(self, &rwvo_);");
  }

  public void testRetainedLocalRef() throws IOException {
    String translation = translateSourceFile(
        "class Test { "
        + "  boolean test1(String s1, String s2) {"
        + "    @com.google.j2objc.annotations.RetainedLocalRef"
        + "    java.util.Comparator<String> c = String.CASE_INSENSITIVE_ORDER;"
        + "    return c.compare(s1, s2) == 0;"
        + "    }   "
        + "  boolean test2(Thing t, Thing t2, String s1, String s2) {"
        + "    @com.google.j2objc.annotations.RetainedLocalRef"
        + "    Thing thing = t;"
        + "    thing = t2;"
        + "    return thing.comp.compare(s1, s2) == 0;"
        + "  }"
        + "  private static class Thing { public java.util.Comparator<String> comp; }}",
        "Test", "Test.m");
    assertNotInTranslation(translation, "RetainedLocalRef");
    assertTranslatedLines(translation,
        "id<JavaUtilComparator> c = JreRetainedLocalValue(JreLoadStatic("
        + "NSString, CASE_INSENSITIVE_ORDER));",
        "return [((id<JavaUtilComparator>) nil_chk(c)) compareWithId:s1 withId:s2] == 0;");
    assertTranslatedLines(translation,
        "Test_Thing *thing = JreRetainedLocalValue(t);",
        "thing = JreRetainedLocalValue(t2);",
        "return [((id<JavaUtilComparator>) nil_chk(((Test_Thing *) nil_chk(thing))->comp_)) "
          + "compareWithId:s1 withId:s2] == 0;");
  }

  public void testRetainedLocalRefStrictField() throws IOException {
    options.setStrictFieldAssign(true);
    options.setStrictFieldLoad(true);
    String translation =
        translateSourceFile(
            "class Test { "
                + "  boolean test1(String s1, String s2) {"
                + "    @com.google.j2objc.annotations.RetainedLocalRef"
                + "    java.util.Comparator<String> c = String.CASE_INSENSITIVE_ORDER;"
                + "    return c.compare(s1, s2) == 0;"
                + "    }   "
                + "  boolean test2(Thing t, Thing t2, String s1, String s2) {"
                + "    @com.google.j2objc.annotations.RetainedLocalRef"
                + "    Thing thing = t;"
                + "    thing = t2;"
                + "    return thing.comp.compare(s1, s2) == 0;"
                + "  }"
                + "  private static class Thing { public java.util.Comparator<String> comp; }}",
            "Test",
            "Test.m");
    assertNotInTranslation(translation, "RetainedLocalRef");
    assertTranslatedLines(
        translation,
        "id<JavaUtilComparator> c = JreStrictFieldStrongLoad(JreLoadStaticRef("
            + "NSString, CASE_INSENSITIVE_ORDER));",
        "return [((id<JavaUtilComparator>) nil_chk(c)) compareWithId:s1 withId:s2] == 0;");
    assertTranslatedLines(
        translation,
        "Test_Thing *thing = JreRetainedLocalValue(t);",
        "thing = JreRetainedLocalValue(t2);",
        "return [((id<JavaUtilComparator>) nil_chk(JreStrictFieldStrongLoad(&((Test_Thing *)"
            + " nil_chk(thing))->comp_))) compareWithId:s1 withId:s2] == 0;");
  }

  // From jre_emul/misc_tests/RetentionTest.java.
  private static final String RETENTION_TEST_SOURCE =
      "class RetentionTest {"
          + "  static class Ref {"
          + "    Object object;"
          + "    Object get() {"
          + "      return object;"
          + "    }"
          + "  }"
          + "  public void testFieldGetter() {"
          + "    Ref ref = new Ref();"
          + "    com.google.j2objc.util.AutoreleasePool.run(() -> {"
          + "      ref.object = new Object();"
          + "    });"
          + "    Object object = ref.get();"
          + "    com.google.j2objc.util.AutoreleasePool.run(() -> {"
          + "      ref.object = null;"
          + "    });"
          + "    object.hashCode();"
          + "  }"
          + "}";

  public void testRetainedLocalRefFieldGetter() throws IOException {
    String translation =
        translateSourceFile(RETENTION_TEST_SOURCE, "RetentionTest", "RetentionTest.m");
    assertTranslation(translation, "id object = JreRetainedLocalValue([ref get]);");
  }

  public void testNoRetainedLocalRefWithARC() throws IOException {
    options.setMemoryManagementOption(MemoryManagementOption.ARC);
    String translation =
        translateSourceFile(RETENTION_TEST_SOURCE, "RetentionTest", "RetentionTest.m");
    assertNotInTranslation(translation, "JreRetainedLocalValue");
  }

  public void testLazyInitFields() throws IOException {
    addSourcesToSourcepaths();
    addSourceFile("package com.google.errorprone.annotations.concurrent;"
        + "public @interface LazyInit {}",
        "com/google/errorprone/annotations/concurrent/LazyInit.java");
    String translation = translateSourceFile(
        "import com.google.errorprone.annotations.concurrent.LazyInit;"
        + "class Test { @LazyInit String lazyStr; @LazyInit static String lazyStaticStr; }",
        "Test", "Test.h");
    assertTranslation(translation, "volatile_id lazyStr_;");
    assertTranslatedLines(translation,
        "FOUNDATION_EXPORT volatile_id Test_lazyStaticStr;",
        "J2OBJC_STATIC_FIELD_OBJ_VOLATILE(Test, lazyStaticStr, NSString *)");
  }

  public void testRetainedLocal_synchronizedBlock() throws IOException {
    String translation = translateSourceFile(
        "class Test {"
        + "  class Foo {}"
        + "  Foo f = new Foo();"
        + "  void test(String s1, char c1) {"
        + "    Foo f1 = new Foo(), f2 = f;"
        + "    synchronized(f1) {"
        + "      f1 = f2;"
        + "      Foo f3 = f2;"
        + "      s1 = \"foo\";"
        + "      c1 = 'a';"
        + "      synchronized(f3) {"
        + "        f3 = f1;"
        + "      }"
        + "      synchronized(f3) {"
        + "        f3 = f2;"
        + "      }"
        + "    }"
        + "    f2 = f1;"
        + "  }"
        + "}", "Test", "Test.m");
    assertTranslation(translation, "Test_Foo *f2 = JreRetainedLocalValue(f_);");
    assertTranslation(translation, "f1 = JreRetainedLocalValue(f2);");
    assertTranslation(translation, "Test_Foo *f3 = JreRetainedLocalValue(f2);");
    assertTranslation(translation, "s1 = @\"foo\";");
    assertTranslation(translation, "c1 = 'a';");
    assertTranslation(translation, "f3 = JreRetainedLocalValue(f1);");
    assertTranslation(translation, "f3 = JreRetainedLocalValue(f2);");
    assertTranslation(translation, "f2 = f1;");
  }

  public void testRetainedLocal_synchronizedBlock_StrictField() throws IOException {
    options.setStrictFieldAssign(true);
    options.setStrictFieldLoad(true);
    String translation =
        translateSourceFile(
            "class Test {"
                + "  class Foo {}"
                + "  Foo f = new Foo();"
                + "  void test(String s1, char c1) {"
                + "    Foo f1 = new Foo(), f2 = f;"
                + "    synchronized(f1) {"
                + "      f1 = f2;"
                + "      Foo f3 = f2;"
                + "      s1 = \"foo\";"
                + "      c1 = 'a';"
                + "      synchronized(f3) {"
                + "        f3 = f1;"
                + "      }"
                + "      synchronized(f3) {"
                + "        f3 = f2;"
                + "      }"
                + "    }"
                + "    f2 = f1;"
                + "  }"
                + "}",
            "Test",
            "Test.m");
    assertTranslation(translation, "Test_Foo *f2 = JreStrictFieldStrongLoad(&f_);");
    assertTranslation(translation, "f1 = JreRetainedLocalValue(f2);");
    assertTranslation(translation, "Test_Foo *f3 = JreRetainedLocalValue(f2);");
    assertTranslation(translation, "s1 = @\"foo\";");
    assertTranslation(translation, "c1 = 'a';");
    assertTranslation(translation, "f3 = JreRetainedLocalValue(f1);");
    assertTranslation(translation, "f3 = JreRetainedLocalValue(f2);");
    assertTranslation(translation, "f2 = f1;");
  }

  public void testRetainedLocal_returnWithinSynchronizedMethodOrBlock() throws IOException {
    String translation = translateSourceFile(
        "class Test {"
        + "  class Foo {}"
        + "  Foo f = new Foo();"
        + "  String test1(String s1, char c1) {"
        + "    synchronized(s1) {"
        + "      return s1;"
        + "    }"
        + "  }"
        + "  synchronized Foo test2() {"
        + "    Foo f1 = f;"
        + "    return f1;"
        + "  }"
        + "  synchronized int test3() {"
        + "    int val = 1;"
        + "    return val;"
        + "  }"
        + "}", "Test", "Test.m");
    assertTranslation(translation, "return JreRetainedLocalValue(s1);");
    assertTranslation(translation, "return JreRetainedLocalValue(f1)");
    assertTranslation(translation, "return val;");
  }

  public void testRetainAutoreleaseReturns() throws IOException {
    options.setRetainAutoreleaseReturns(true);
    String translation =
        translateSourceFile(
            "class Test {"
                + "  class Foo {}"
                + "  Foo f = new Foo();"
                + "  String test1(String s1, char c1) {"
                + "    return s1;"
                + "  }"
                + "  Foo test2() {"
                + "    Foo f1 = f;"
                + "    return f1;"
                + "  }"
                + "  Foo test3() {"
                + "    return test2();"
                + "  }"
                + "  String test4() {"
                + "    return \"bar\";"
                + "  }"
                + "  int test5() {"
                + "    int val = 1;"
                + "    return val;"
                + "  }"
                + "}",
            "Test",
            "Test.m");
    assertTranslation(translation, "return JreRetainedAutoreleasedReturnValue(s1);");
    assertTranslation(translation, "return JreRetainedAutoreleasedReturnValue(f1)");
    assertTranslation(translation, "return [self test2]");
    assertTranslation(translation, "return @\"bar\"");
    assertTranslation(translation, "return val;");
  }

  public void testRetainAutoreleaseReturnsARC() throws IOException {
    options.setMemoryManagementOption(MemoryManagementOption.ARC);
    options.setRetainAutoreleaseReturns(true);
    String translation =
        translateSourceFile(
            "class Test {"
                + "  class Foo {}"
                + "  Foo f = new Foo();"
                + "  String test1(String s1, char c1) {"
                + "    return s1;"
                + "  }"
                + "  Foo test2() {"
                + "    Foo f1 = f;"
                + "    return f1;"
                + "  }"
                + "  Foo test3() {"
                + "    return test2();"
                + "  }"
                + "  String test4() {"
                + "    return \"bar\";"
                + "  }"
                + "  int test5() {"
                + "    int val = 1;"
                + "    return val;"
                + "  }"
                + "}",
            "Test",
            "Test.m");
    assertTranslation(translation, "return s1;");
    assertTranslation(translation, "return f1");
    assertTranslation(translation, "return [self test2]");
    assertTranslation(translation, "return @\"bar\"");
    assertTranslation(translation, "return val;");
  }

  public void testObjectEquality() throws IOException {
    String translation = translateSourceFile(
        "class Test {"
            + "  boolean testStringEquals(String s1, String s2) {"
            + "    return s1 == s2;"
            + "  }"
            + "  boolean testObjectEquals(Object o1, Object o2) {"
            + "    return o1 == o2;"
            + "  }"
            + "  boolean testObjectEqualsString(String s3, Object o3) {"
            + "    return s3 == o3;"
            + "  }"
            + "  boolean testObjectEqualsNull(Object o4) {"
            + "    return o4 == null;"
            + "  }"
            + "  boolean testPrimitiveEquals(int i1, int i2) {"
            + "    return i1 == i2;"
            + "  }"
            + "  boolean testStringNotEquals(String s5, String s6) {"
            + "    return s5 != s6;"
            + "  }"
            + "  boolean testObjectNotEquals(Object o5, Object o6) {"
            + "    return o5 != o6;"
            + "  }"
            + "  boolean testObjectNotEqualsString(String s7, Object o7) {"
            + "    return s7 != o7;"
            + "  }"
            + "  boolean testObjectNotEqualsNull(Object o8) {"
            + "    return o8 != null;"
            + "  }"
            + "  boolean testPrimitiveNotEquals(int i3, int i4) {"
            + "    return i3 != i4;"
            + "  }"
            + "}", "Test", "Test.m");
    assertTranslation(translation, "return JreStringEqualsEquals(s1, s2);");
    assertTranslation(translation, "return JreObjectEqualsEquals(o1, o2);");
    assertTranslation(translation, "return JreObjectEqualsEquals(s3, o3);");
    assertTranslation(translation, "return o4 == nil;");
    assertTranslation(translation, "return i1 == i2;");
    assertTranslation(translation, "return !JreStringEqualsEquals(s5, s6);");
    assertTranslation(translation, "return !JreObjectEqualsEquals(o5, o6);");
    assertTranslation(translation, "return !JreObjectEqualsEquals(s7, o7);");
    assertTranslation(translation, "return o8 != nil;");
    assertTranslation(translation, "return i3 != i4;");
  }

  public void testEqualOperator() throws IOException {
    String translation =
        translateSourceFile(
            "class Test {"
                + "  Boolean testBooleanEquals(Boolean b1, Boolean b2) {"
                + "    return b1 == b2;"
                + "  }"
                + "  Boolean testNestedBooleanEquals(Boolean b1, Boolean b2, Boolean b3) {"
                + "    return b1 == b2 == b3;"
                + "  }"
                + "  Boolean testNestedBoolean(Boolean b1, Boolean b2, Boolean b3) {"
                + "    return b1 != b2 == b3;"
                + "  }"
                + "  Boolean testStringBooleanEquals(Boolean s1, Boolean s2, Boolean b3) {"
                + "    return s1 == s2 == b3;"
                + "  }"
                + "  Boolean testBooleanNotEquals(Boolean b1, Boolean b2) {"
                + "    return b1 != b2;"
                + "  }"
                + "  Boolean testNestedBooleanNotEquals(Boolean b1, Boolean b2, Boolean b3) {"
                + "    return b1 != b2 != b3;"
                + "  }"
                + "}",
            "Test",
            "Test.m");
    assertTranslation(
        translation, "return JavaLangBoolean_valueOfWithBoolean_(JreObjectEqualsEquals(b1, b2));");
    assertTranslation(
        translation,
        "return JavaLangBoolean_valueOfWithBoolean_(JreObjectEqualsEquals(b1, b2) =="
            + " [((JavaLangBoolean *) nil_chk(b3)) booleanValue]);");
    assertTranslation(
        translation,
        "return JavaLangBoolean_valueOfWithBoolean_(!JreObjectEqualsEquals(b1, b2) =="
            + " [((JavaLangBoolean *) nil_chk(b3)) booleanValue]);");
    assertTranslation(
        translation,
        "return JavaLangBoolean_valueOfWithBoolean_(JreObjectEqualsEquals(s1, s2) =="
            + " [((JavaLangBoolean *) nil_chk(b3)) booleanValue]);");
    assertTranslation(
        translation, "return JavaLangBoolean_valueOfWithBoolean_(!JreObjectEqualsEquals(b1, b2));");
    assertTranslation(
        translation,
        "return JavaLangBoolean_valueOfWithBoolean_(!JreObjectEqualsEquals(b1, b2) !="
            + " [((JavaLangBoolean *) nil_chk(b3)) booleanValue]);");
  }

  /**
   * Regression test for b/239746548. Issue was that an annotation with a TYPE_USE target
   * caused javac to change the annotation type's toString() method.
   */
  public void testAnnotatedTypeUseVolatileLoad() throws IOException {
    addSourceFile(
        "import java.lang.annotation.Target; "
            + "import static java.lang.annotation.ElementType.*; "
            + "@Target({FIELD, TYPE_USE})"
            + "public @interface Simple {}",
        "Simple.java");
    String translation =
        translateSourceFile(
            "class Test { "
                + "@Simple private volatile boolean isClosed; "
                + "  public void close() {"
                + "    if (!isClosed) {"
                + "      isClosed = true;"
                + "    }"
                + "  }}",
            "Test",
            "Test.m");
    assertNotInTranslation(translation, "JreLoadVolatile(@Simple :: boolean)(&isClosed_)");
    assertTranslatedLines(translation,
        "if (!JreLoadVolatileBoolean(&isClosed_)) {",
        "JreAssignVolatileBoolean(&isClosed_, true);",
        "}");
  }
}
