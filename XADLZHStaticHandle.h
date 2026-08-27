/*
 * XADLZHStaticHandle.h
 *
 * Copyright (c) 2017-present, MacPaw Inc. All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301  USA
 */
// [cooViewer] lh4-7(および ARJ/Zoo の同型 LZH)を per-byte の XADLZSSHandle から
// バッチ展開の XADFastLZSSHandle へ移植(cooViewer-7ni)。マッチコピーが LZSS.h の
// memcpy/memset 高速路に乗り、CSByteStreamHandle の 1 バイト 1 IMP 呼び出しが消える。
// デコードのシンボル解釈・窓・オフセット/長さは不変(バイト同一)。
#import "XADFastLZSSHandle.h"
#import "XADPrefixCode.h"

@interface XADLZHStaticHandle:XADFastLZSSHandle
{
	XADPrefixCode *literalcode,*distancecode;
	int blocksize,blockpos;
	int windowbits;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length windowBits:(int)bits;
-(void)dealloc;

-(void)resetLZSSHandle;
-(void)expandFromPosition:(off_t)pos;

-(XADPrefixCode *)allocAndParseCodeOfWidth:(int)bits specialIndex:(int)specialindex;
-(XADPrefixCode *)allocAndParseLiteralCode;

@end
