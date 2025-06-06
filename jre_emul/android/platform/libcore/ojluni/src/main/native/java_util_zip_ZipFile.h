/* This file was generated from java/util/zip/ZipFile.java and is licensed
 * under the same terms. The copyright and license information for
 * java/util/zip/ZipFile.java follows.
 *
 * Copyright (c) 1995, 2011, Oracle and/or its affiliates. All rights reserved.
 * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS FILE HEADER.
 *
 * This code is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 2 only, as
 * published by the Free Software Foundation.  Oracle designates this
 * particular file as subject to the "Classpath" exception as provided
 * by Oracle in the LICENSE file that accompanied this code.
 *
 * This code is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * version 2 for more details (a copy is included in the LICENSE file that
 * accompanied this code).
 *
 * You should have received a copy of the GNU General Public License version
 * 2 along with this work; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA.
 *
 * Please contact Oracle, 500 Oracle Parkway, Redwood Shores, CA 94065 USA
 * or visit www.oracle.com if you need additional information or have any
 * questions.
 */
/* DO NOT EDIT THIS FILE - it is machine generated */
#include <jni.h>
/* Header for class java_util_zip_ZipFile */

#ifndef _Included_java_util_zip_ZipFile
#define _Included_java_util_zip_ZipFile
#ifdef __cplusplus
extern "C" {
#endif
#undef java_util_zip_ZipFile_STORED
#define java_util_zip_ZipFile_STORED 0L
#undef java_util_zip_ZipFile_DEFLATED
#define java_util_zip_ZipFile_DEFLATED 8L
#undef java_util_zip_ZipFile_OPEN_READ
#define java_util_zip_ZipFile_OPEN_READ 1L
#undef java_util_zip_ZipFile_OPEN_DELETE
#define java_util_zip_ZipFile_OPEN_DELETE 4L
#undef java_util_zip_ZipFile_JZENTRY_NAME
#define java_util_zip_ZipFile_JZENTRY_NAME 0L
#undef java_util_zip_ZipFile_JZENTRY_EXTRA
#define java_util_zip_ZipFile_JZENTRY_EXTRA 1L
#undef java_util_zip_ZipFile_JZENTRY_COMMENT
#define java_util_zip_ZipFile_JZENTRY_COMMENT 2L

/*
 * Class:     java_util_zip_ZipFile
 * Method:    getEntry
 * Signature: (J[BZ)J
 */
JNIEXPORT jlong JNICALL ZipFile_getEntry(JNIEnv *, jclass, jlong, jbyteArray,
                                         bool);

/*
 * Class:     java_util_zip_ZipFile
 * Method:    freeEntry
 * Signature: (JJ)V
 */
JNIEXPORT void JNICALL ZipFile_freeEntry
  (JNIEnv *, jclass, jlong, jlong);

/*
 * Class:     java_util_zip_ZipFile
 * Method:    getNextEntry
 * Signature: (JI)J
 */
JNIEXPORT jlong JNICALL ZipFile_getNextEntry
  (JNIEnv *, jclass, jlong, jint);

/*
 * Class:     java_util_zip_ZipFile
 * Method:    close
 * Signature: (J)V
 */
JNIEXPORT void JNICALL ZipFile_close
  (JNIEnv *, jclass, jlong);

/*
 * Class:     java_util_zip_ZipFile
 * Method:    open
 * Signature: (Ljava/lang/String;IJZ)J
 */
JNIEXPORT jlong JNICALL ZipFile_open(JNIEnv *, jclass, jstring, jint, jlong,
                                     bool);

/*
 * Class:     java_util_zip_ZipFile
 * Method:    getTotal
 * Signature: (J)I
 */
JNIEXPORT jint JNICALL ZipFile_getTotal
  (JNIEnv *, jclass, jlong);

/*
 * Class:     java_util_zip_ZipFile
 * Method:    startsWithLOC
 * Signature: (J)Z
 */
JNIEXPORT bool JNICALL ZipFile_startsWithLOC(JNIEnv *, jclass, jlong);

/*
 * Class:     java_util_zip_ZipFile
 * Method:    read
 * Signature: (JJJ[BII)I
 */
JNIEXPORT jint JNICALL ZipFile_read
  (JNIEnv *, jclass, jlong, jlong, jlong, jbyteArray, jint, jint);

/*
 * Class:     java_util_zip_ZipFile
 * Method:    getEntryTime
 * Signature: (J)J
 */
JNIEXPORT jlong JNICALL ZipFile_getEntryTime
  (JNIEnv *, jclass, jlong);

/*
 * Class:     java_util_zip_ZipFile
 * Method:    getEntryCrc
 * Signature: (J)J
 */
JNIEXPORT jlong JNICALL ZipFile_getEntryCrc
  (JNIEnv *, jclass, jlong);

/*
 * Class:     java_util_zip_ZipFile
 * Method:    getEntryCSize
 * Signature: (J)J
 */
JNIEXPORT jlong JNICALL ZipFile_getEntryCSize
  (JNIEnv *, jclass, jlong);

/*
 * Class:     java_util_zip_ZipFile
 * Method:    getEntrySize
 * Signature: (J)J
 */
JNIEXPORT jlong JNICALL ZipFile_getEntrySize
  (JNIEnv *, jclass, jlong);

/*
 * Class:     java_util_zip_ZipFile
 * Method:    getEntryMethod
 * Signature: (J)I
 */
JNIEXPORT jint JNICALL ZipFile_getEntryMethod
  (JNIEnv *, jclass, jlong);

/*
 * Class:     java_util_zip_ZipFile
 * Method:    getEntryFlag
 * Signature: (J)I
 */
JNIEXPORT jint JNICALL ZipFile_getEntryFlag
  (JNIEnv *, jclass, jlong);

/*
 * Class:     java_util_zip_ZipFile
 * Method:    getCommentBytes
 * Signature: (J)[B
 */
JNIEXPORT jbyteArray JNICALL ZipFile_getCommentBytes
  (JNIEnv *, jclass, jlong);

/*
 * Class:     java_util_zip_ZipFile
 * Method:    getEntryBytes
 * Signature: (JI)[B
 */
JNIEXPORT jbyteArray JNICALL ZipFile_getEntryBytes
  (JNIEnv *, jclass, jlong, jint);

/*
 * Class:     java_util_zip_ZipFile
 * Method:    getZipMessage
 * Signature: (J)Ljava/lang/String;
 */
JNIEXPORT jstring JNICALL ZipFile_getZipMessage
  (JNIEnv *, jclass, jlong);

#ifdef __cplusplus
}
#endif
#endif
