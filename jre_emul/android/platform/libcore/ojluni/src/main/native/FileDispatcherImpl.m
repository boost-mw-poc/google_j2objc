/*
 * Copyright (c) 2000, 2009, Oracle and/or its affiliates. All rights reserved.
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

#include "jni.h"
#include "jni_util.h"
#include "jvm.h"
#include "jlong.h"
#include "sun_nio_ch_FileDispatcherImpl.h"
#include "java_lang_Long.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <fcntl.h>
#include <sys/uio.h>
#include <unistd.h>
#include "nio.h"
#include "nio_util.h"

#define NATIVE_METHOD(className, functionName, signature) \
{ #functionName, signature, (void*)(className ## _ ## functionName) }

//#ifdef _ALLBSD_SOURCE
#define stat64 stat
#define flock64 flock
#define off64_t off_t
#define F_SETLKW64 F_SETLKW
#define F_SETLK64 F_SETLK

#define pread64 pread
#define pwrite64 pwrite
#define ftruncate64 ftruncate
#define fstat64 fstat

#define fdatasync fsync
//#endif

JNIEXPORT jint JNICALL
Java_sun_nio_ch_FileDispatcherImpl_read0(JNIEnv *env, jclass clazz,
                             jobject fdo, jlong address, jint len)
{
    jint fd = fdval(env, fdo);
    void *buf = (void *)jlong_to_ptr(address);

    return convertReturnVal(env, (int)read(fd, buf, len), JNI_TRUE);
}

JNIEXPORT jint JNICALL
Java_sun_nio_ch_FileDispatcherImpl_pread0(JNIEnv *env, jclass clazz, jobject fdo,
                            jlong address, jint len, jlong offset)
{
    jint fd = fdval(env, fdo);
    void *buf = (void *)jlong_to_ptr(address);

    return convertReturnVal(env, (int)pread64(fd, buf, len, offset), JNI_TRUE);
}

JNIEXPORT jlong JNICALL
Java_sun_nio_ch_FileDispatcherImpl_readv0(JNIEnv *env, jclass clazz,
                              jobject fdo, jlong address, jint len)
{
    jint fd = fdval(env, fdo);
    struct iovec *iov = (struct iovec *)jlong_to_ptr(address);
    return convertLongReturnVal(env, readv(fd, iov, len), JNI_TRUE);
}

JNIEXPORT jint JNICALL
Java_sun_nio_ch_FileDispatcherImpl_write0(JNIEnv *env, jclass clazz,
                              jobject fdo, jlong address, jint len)
{
    jint fd = fdval(env, fdo);
    void *buf = (void *)jlong_to_ptr(address);

    return convertReturnVal(env, (int)write(fd, buf, len), JNI_FALSE);
}

JNIEXPORT jint JNICALL
Java_sun_nio_ch_FileDispatcherImpl_pwrite0(JNIEnv *env, jclass clazz, jobject fdo,
                            jlong address, jint len, jlong offset)
{
    jint fd = fdval(env, fdo);
    void *buf = (void *)jlong_to_ptr(address);

    return convertReturnVal(env, (int)pwrite64(fd, buf, len, offset), JNI_FALSE);
}

JNIEXPORT jlong JNICALL
Java_sun_nio_ch_FileDispatcherImpl_writev0(JNIEnv *env, jclass clazz,
                                       jobject fdo, jlong address, jint len)
{
    jint fd = fdval(env, fdo);
    struct iovec *iov = (struct iovec *)jlong_to_ptr(address);
    return convertLongReturnVal(env, (int)writev(fd, iov, len), JNI_FALSE);
}

static jlong
handle(JNIEnv *env, jlong rv, char *msg)
{
    if (rv >= 0)
        return rv;
    if (errno == EINTR)
        return IOS_INTERRUPTED;
    JNU_ThrowIOExceptionWithLastError(env, msg);
    return IOS_THROWN;
}

JNIEXPORT jint JNICALL Java_sun_nio_ch_FileDispatcherImpl_force0(JNIEnv *env, jobject this,
                                                                 jobject fdo, bool md) {
  jint fd = fdval(env, fdo);
  int result = 0;

  if (md == JNI_FALSE) {
    result = fdatasync(fd);
  } else {
    result = fsync(fd);
  }
  return (int)handle(env, result, "Force failed");
}

JNIEXPORT jint JNICALL
Java_sun_nio_ch_FileDispatcherImpl_truncate0(JNIEnv *env, jobject this,
                                             jobject fdo, jlong size)
{
    return (int)handle(env,
                  ftruncate64(fdval(env, fdo), size),
                  "Truncation failed");
}

JNIEXPORT jlong JNICALL
Java_sun_nio_ch_FileDispatcherImpl_size0(JNIEnv *env, jobject this, jobject fdo)
{
    struct stat64 fbuf;

    if (fstat64(fdval(env, fdo), &fbuf) < 0)
        return handle(env, -1, "Size failed");
    return fbuf.st_size;
}

JNIEXPORT jint JNICALL Java_sun_nio_ch_FileDispatcherImpl_lock0(JNIEnv *env, jobject this,
                                                                jobject fdo, bool block, jlong pos,
                                                                jlong size, bool shared) {
  jint fd = fdval(env, fdo);
  jint lockResult = 0;
  int cmd = 0;
  struct flock64 fl;

  fl.l_whence = SEEK_SET;
  if (size == (jlong)java_lang_Long_MAX_VALUE) {
    fl.l_len = (off64_t)0;
  } else {
    fl.l_len = (off64_t)size;
  }
  fl.l_start = (off64_t)pos;
  if (shared == JNI_TRUE) {
    fl.l_type = F_RDLCK;
  } else {
    fl.l_type = F_WRLCK;
  }
  if (block == JNI_TRUE) {
    cmd = F_SETLKW64;
  } else {
    cmd = F_SETLK64;
  }
  lockResult = fcntl(fd, cmd, &fl);
  if (lockResult < 0) {
    if ((cmd == F_SETLK64) && (errno == EAGAIN || errno == EACCES))
      return sun_nio_ch_FileDispatcherImpl_NO_LOCK;
    if (errno == EINTR) return sun_nio_ch_FileDispatcherImpl_INTERRUPTED;
    JNU_ThrowIOExceptionWithLastError(env, "Lock failed");
  }
  return 0;
}

JNIEXPORT void JNICALL
Java_sun_nio_ch_FileDispatcherImpl_release0(JNIEnv *env, jobject this,
                                         jobject fdo, jlong pos, jlong size)
{
    jint fd = fdval(env, fdo);
    jint lockResult = 0;
    struct flock64 fl;
    int cmd = F_SETLK64;

    fl.l_whence = SEEK_SET;
    if (size == (jlong)java_lang_Long_MAX_VALUE) {
        fl.l_len = (off64_t)0;
    } else {
        fl.l_len = (off64_t)size;
    }
    fl.l_start = (off64_t)pos;
    fl.l_type = F_UNLCK;
    lockResult = fcntl(fd, cmd, &fl);
    if (lockResult < 0) {
        JNU_ThrowIOExceptionWithLastError(env, "Release failed");
    }
}


static void closeFileDescriptor(JNIEnv *env, int fd) {
    if (fd != -1) {
        int result = close(fd);
        if (result < 0)
            JNU_ThrowIOExceptionWithLastError(env, "Close failed");
    }
}

JNIEXPORT void JNICALL
Java_sun_nio_ch_FileDispatcherImpl_close0(JNIEnv *env, jclass clazz, jobject fdo)
{
    jint fd = fdval(env, fdo);
    closeFileDescriptor(env, fd);
}

JNIEXPORT void JNICALL
Java_sun_nio_ch_FileDispatcherImpl_preClose0(JNIEnv *env, jclass clazz, jobject fdo)
{
    jint fd = fdval(env, fdo);
    int preCloseFD = open("/dev/null", O_RDWR | O_CLOEXEC);
    if (preCloseFD < 0) {
        JNU_ThrowIOExceptionWithLastError(env, "open(\"/dev/null\") failed");
        return;
    }
    if (dup2(preCloseFD, fd) < 0) {
        JNU_ThrowIOExceptionWithLastError(env, "dup2 failed");
    }
    close(preCloseFD);
}

JNIEXPORT void JNICALL
Java_sun_nio_ch_FileDispatcherImpl_closeIntFD(JNIEnv *env, jclass clazz, jint fd)
{
    closeFileDescriptor(env, fd);
}

/* J2ObjC: unused.
static JNINativeMethod gMethods[] = {
  NATIVE_METHOD(FileDispatcherImpl, closeIntFD, "(I)V"),
  NATIVE_METHOD(FileDispatcherImpl, preClose0, "(Ljava/io/FileDescriptor;)V"),
  NATIVE_METHOD(FileDispatcherImpl, close0, "(Ljava/io/FileDescriptor;)V"),
  NATIVE_METHOD(FileDispatcherImpl, release0, "(Ljava/io/FileDescriptor;JJ)V"),
  NATIVE_METHOD(FileDispatcherImpl, lock0, "(Ljava/io/FileDescriptor;ZJJZ)I"),
  NATIVE_METHOD(FileDispatcherImpl, size0, "(Ljava/io/FileDescriptor;)J"),
  NATIVE_METHOD(FileDispatcherImpl, truncate0, "(Ljava/io/FileDescriptor;J)I"),
  NATIVE_METHOD(FileDispatcherImpl, force0, "(Ljava/io/FileDescriptor;Z)I"),
  NATIVE_METHOD(FileDispatcherImpl, writev0, "(Ljava/io/FileDescriptor;JI)J"),
  NATIVE_METHOD(FileDispatcherImpl, pwrite0, "(Ljava/io/FileDescriptor;JIJ)I"),
  NATIVE_METHOD(FileDispatcherImpl, write0, "(Ljava/io/FileDescriptor;JI)I"),
  NATIVE_METHOD(FileDispatcherImpl, readv0, "(Ljava/io/FileDescriptor;JI)J"),
  NATIVE_METHOD(FileDispatcherImpl, pread0, "(Ljava/io/FileDescriptor;JIJ)I"),
  NATIVE_METHOD(FileDispatcherImpl, read0, "(Ljava/io/FileDescriptor;JI)I"),
};

void register_sun_nio_ch_FileDispatcherImpl(JNIEnv* env) {
  jniRegisterNativeMethods(env, "sun/nio/ch/FileDispatcherImpl", gMethods, NELEM(gMethods));
}
*/
