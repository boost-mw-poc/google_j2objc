/*
 * Copyright (c) 1997, 2012, Oracle and/or its affiliates. All rights reserved.
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

#ifndef NET_UTILS_H
#define NET_UTILS_H

#include "jvm.h"
#include "jni_util.h"
#include "net_util_md.h"

/************************************************************************
 * Macros and misc constants
 */

#define MAX_PACKET_LEN 65536

#define IPv4 AF_INET
#define IPv6 AF_INET6

#define NET_ERROR(env, ex, msg) \
{ if (!(*env)->ExceptionOccurred(env)) JNU_ThrowByName(env, ex, msg); }

/************************************************************************
 * Cached field IDs
 *
 * The naming convention for field IDs is
 *      <class abbrv>_<fieldName>ID
 * i.e. psi_timeoutID is PlainSocketImpl's timeout field's ID.
 */
/* J2ObjC: unused.
extern jclass ia_class;
extern jfieldID iac_addressID;
extern jfieldID iac_familyID;
extern jfieldID iac_hostNameID;
extern jfieldID ia_preferIPv6AddressID;
*/

extern void setInetAddress_addr(JNIEnv *env, jobject iaObj, int address);
extern void setInetAddress_family(JNIEnv *env, jobject iaObj, int family);
extern void setInetAddress_hostName(JNIEnv *env, jobject iaObj, jobject h);
extern int getInetAddress_addr(JNIEnv *env, jobject iaObj);
extern int getInetAddress_family(JNIEnv *env, jobject iaObj);
extern jobject getInetAddress_hostName(JNIEnv *env, jobject iaObj);

/* J2ObjC: unused.
extern jclass ia4_class;
extern jmethodID ia4_ctrID;
*/

/* NetworkInterface fields */
extern jclass ni_class;
extern jfieldID ni_nameID;
extern jfieldID ni_indexID;
extern jfieldID ni_addrsID;
extern jfieldID ni_descID;
extern jmethodID ni_ctrID;

/* PlainSocketImpl fields */
extern jfieldID psi_timeoutID;
extern jfieldID psi_fdID;
extern jfieldID psi_addressID;
extern jfieldID psi_portID;
extern jfieldID psi_localportID;

/* DatagramPacket fields */
extern jfieldID dp_addressID;
extern jfieldID dp_portID;
extern jfieldID dp_bufID;
extern jfieldID dp_offsetID;
extern jfieldID dp_lengthID;
extern jfieldID dp_bufLengthID;

/* Inet6Address fields */
extern jclass ia6_class;
extern jfieldID ia6_ipaddressID;
extern jfieldID ia6_scopeidID;
extern jfieldID ia6_scopeidsetID;
extern jfieldID ia6_scopeifnameID;
extern jfieldID ia6_scopeifnamesetID;
extern jmethodID ia6_ctrID;

/************************************************************************
 *  Utilities
 */

JNIEXPORT void JNICALL NET_ThrowNew(JNIEnv *env, int errorNum, char *msg);
int NET_GetError(void);

void NET_ThrowCurrent(JNIEnv *env, char *msg);

jfieldID NET_GetFileDescriptorID(JNIEnv *env);

JNIEXPORT jint JNICALL ipv6_available(void);

void
NET_AllocSockaddr(struct sockaddr **him, int *len);

JNIEXPORT int JNICALL NET_InetAddressToSockaddr(JNIEnv *env, jobject iaObj,
                                                int port, struct sockaddr *him,
                                                int *len, bool v4MappedAddress);

JNIEXPORT jobject JNICALL
NET_SockaddrToInetAddress(JNIEnv *env, struct sockaddr *him, int *port);

void initLocalAddrTable(void);
void parseExclusiveBindProperty(JNIEnv *env);

void
NET_SetTrafficClass(struct sockaddr *him, int trafficClass);

JNIEXPORT jint JNICALL
NET_GetPortFromSockaddr(struct sockaddr *him);

JNIEXPORT jint JNICALL
NET_SockaddrEqualsInetAddress(JNIEnv *env,struct sockaddr *him, jobject iaObj);

int
NET_IsIPv4Mapped(jbyte* caddr);

int
NET_IPv4MappedToIPv4(jbyte* caddr);

int
NET_IsEqual(jbyte* caddr1, jbyte* caddr2);

int
NET_IsZeroAddr(jbyte* caddr);

/* Socket operations
 *
 * These work just like the JVM_* procedures, except that they may do some
 * platform-specific pre/post processing of the arguments and/or results.
 */

JNIEXPORT int JNICALL
NET_GetSockOpt(int fd, int level, int opt, void *result, int *len);

JNIEXPORT int JNICALL
NET_SetSockOpt(int fd, int level, int opt, const void *arg, int len);

JNIEXPORT int JNICALL
NET_Bind(int fd, struct sockaddr *him, int len);

JNIEXPORT int JNICALL
NET_MapSocketOption(jint cmd, int *level, int *optname);

JNIEXPORT int JNICALL
NET_MapSocketOptionV6(jint cmd, int *level, int *optname);

int getScopeID (struct sockaddr *);

int cmpScopeID (unsigned int, struct sockaddr *);

unsigned short in_cksum(unsigned short *addr, int len);
#endif /* NET_UTILS_H */
