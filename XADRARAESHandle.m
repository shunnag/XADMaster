/*
 * XADRARAESHandle.m
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
#import "XADRARAESHandle.h"
#import "XADException.h"

#ifdef __APPLE__
#import <CommonCrypto/CommonDigest.h>
#endif
#import "RARBug.h"

#import "Crypto/sha.h"

@implementation XADRARAESHandle

+(NSData *)keyForPassword:(NSString *)password salt:(NSData *)salt brokenHash:(BOOL)brokenhash
{
	// [cooViewer] Process-global cache of derived keys: the derivation costs 2^18
	// chained SHA-1 rounds per (password, salt) pair, RAR3 salts are per file, and
	// the parallel extractor pool re-opens the same archive up to 6 times — without
	// this every pool member re-derived every file's key. Locked; keys live as long
	// as the process, like the passwords they derive from.
	static NSMutableDictionary *keycache=nil;
	static NSLock *keycachelock=nil;
	static dispatch_once_t keycacheonce;
	dispatch_once(&keycacheonce,^{
		keycache=[NSMutableDictionary new];
		keycachelock=[NSLock new];
	});
	NSArray *cachekey=[NSArray arrayWithObjects:
		password?password:@"",salt?salt:[NSData data],
		[NSNumber numberWithBool:brokenhash],nil];
	[keycachelock lock];
	NSData *cached=[[[keycache objectForKey:cachekey] retain] autorelease];
	[keycachelock unlock];
	if(cached) return cached;

	uint8_t keybuf[2*16];

	int length=[password length];
	if(length>126) length=126;

	uint8_t passbuf[length*2+8];
	for(int i=0;i<length;i++)
	{
		int c=[password characterAtIndex:i];
		passbuf[2*i]=c;
		passbuf[2*i+1]=c>>8;
	}

	int buflength=length*2;

	if(salt)
	{
		memcpy(passbuf+2*length,[salt bytes],8);
		buflength+=8;
	}

#ifdef __APPLE__
	if(!brokenhash)
	{
		// [cooViewer] With the bug emulation off (RAR >= 3.6 — every modern archive)
		// the stream is plain SHA-1 over 2^18 repetitions of (passbuf | 3-byte round
		// counter) with a snapshot digest every 2^14 rounds. Feed it through hardware
		// SHA-1 (CommonCrypto) in batched buffers — bit-identical to the loop below.
		int recordlength=buflength+3;
		enum { RoundsPerSegment=0x4000, Segments=0x40000/0x4000 };
		uint8_t *batch=malloc((size_t)RoundsPerSegment*recordlength);
		if(batch)
		{
			for(int r=0;r<RoundsPerSegment;r++)
			memcpy(&batch[(size_t)r*recordlength],passbuf,buflength);

			CC_SHA1_CTX sha;
			CC_SHA1_Init(&sha);
			for(int segment=0;segment<Segments;segment++)
			{
				int base=segment*RoundsPerSegment;
				// 全ラウンドの counter を先に埋める(この batch は 1 セグメント分)
				for(int r=0;r<RoundsPerSegment;r++)
				{
					int i=base+r;
					uint8_t *counter=&batch[(size_t)r*recordlength+buflength];
					counter[0]=i; counter[1]=i>>8; counter[2]=i>>16;
				}
				// 元ループと同じ順序: ラウンド base を処理 → その直後にスナップショット
				// (keybuf[segment]=round base 処理後の digest[19])→ 残りをまとめて処理
				CC_SHA1_Update(&sha,batch,(CC_LONG)recordlength);
				CC_SHA1_CTX tmpsha=sha;
				uint8_t digest[CC_SHA1_DIGEST_LENGTH];
				CC_SHA1_Final(digest,&tmpsha);
				keybuf[segment]=digest[19];
				CC_SHA1_Update(&sha,&batch[recordlength],
				(CC_LONG)((size_t)(RoundsPerSegment-1)*recordlength));
			}
			free(batch);

			uint8_t digest[CC_SHA1_DIGEST_LENGTH];
			CC_SHA1_Final(digest,&sha);
			for(int i=0;i<16;i++) keybuf[i+16]=digest[i^3];

			NSData *result=[NSData dataWithBytes:keybuf length:sizeof(keybuf)];
			[keycachelock lock];
			[keycache setObject:result forKey:cachekey];
			[keycachelock unlock];
			return result;
		}
		// malloc 失敗時は従来ループへ
	}
#endif

	SHA_CTX sha;
	SHA1_Init(&sha);

	for(int i=0;i<0x40000;i++)
	{
		SHA1_Update_WithRARBug(&sha,passbuf,buflength,brokenhash);

		uint8_t num[3]={i,i>>8,i>>16};
		SHA1_Update_WithRARBug(&sha,num,3,brokenhash);

		if(i%0x4000==0)
		{
			SHA_CTX tmpsha=sha;
			uint8_t digest[20];
			SHA1_Final(digest,&tmpsha);
			keybuf[i/0x4000]=digest[19];
		}
	}

	uint8_t digest[20];
	SHA1_Final(digest,&sha);

	for(int i=0;i<16;i++) keybuf[i+16]=digest[i^3];

	NSData *result=[NSData dataWithBytes:keybuf length:sizeof(keybuf)];
	[keycachelock lock];
	[keycache setObject:result forKey:cachekey];
	[keycachelock unlock];
	return result;
}

-(id)initWithHandle:(CSHandle *)handle key:(NSData *)keydata
{
	return [self initWithHandle:handle length:CSHandleMaxLength key:keydata];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length key:(NSData *)keydata
{
	if((self=[super initWithParentHandle:handle length:length]))
	{
		startoffs=[handle offsetInFile];

		const uint8_t *keybytes=[keydata bytes];
		memcpy(iv,&keybytes[0],16);
#ifdef __APPLE__
		// [cooViewer] hardware AES via CommonCrypto (same AES-128-CBC, no padding);
		// the vendored implementation stays as the fallback and for other platforms.
		cryptor=NULL;
		if(CCCryptorCreateWithMode(kCCDecrypt,kCCModeCBC,kCCAlgorithmAES,ccNoPadding,
		iv,&keybytes[16],16,NULL,0,0,0,&cryptor)!=kCCSuccess) cryptor=NULL;
		if(!cryptor) aes_decrypt_key128(&keybytes[16],&aes);
#else
		aes_decrypt_key128(&keybytes[16],&aes);
#endif
	}
	return self;
}

-(id)initWithHandle:(CSHandle *)handle RAR5Key:(NSData *)keydata IV:(NSData *)ivdata
{
	return [self initWithHandle:handle length:CSHandleMaxLength RAR5Key:keydata IV:ivdata];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length RAR5Key:(NSData *)keydata IV:(NSData *)ivdata
{
	if(self=[super initWithParentHandle:handle length:length])
	{
		startoffs=[handle offsetInFile];

		memcpy(iv,[ivdata bytes],16);
#ifdef __APPLE__
		cryptor=NULL;
		if(CCCryptorCreateWithMode(kCCDecrypt,kCCModeCBC,kCCAlgorithmAES,ccNoPadding,
		iv,[keydata bytes],32,NULL,0,0,0,&cryptor)!=kCCSuccess) cryptor=NULL;
		if(!cryptor) aes_decrypt_key256([keydata bytes],&aes);
#else
		aes_decrypt_key256([keydata bytes],&aes);
#endif
	}
	return self;
}

#ifdef __APPLE__
-(void)dealloc
{
	if(cryptor) CCCryptorRelease(cryptor);
	[super dealloc];
}
#endif

-(void)resetStream
{
	[parent seekToFileOffset:startoffs];
	memcpy(block,iv,sizeof(iv));
#ifdef __APPLE__
	if(cryptor) CCCryptorReset(cryptor,iv);
#endif
}

// [cooViewer] one CBC decrypt for both backends; keeps the two call sites identical
-(void)decryptCBC:(uint8_t *)bytes length:(int)length
{
#ifdef __APPLE__
	if(cryptor)
	{
		size_t moved=0;
		if(CCCryptorUpdate(cryptor,bytes,length,bytes,length,&moved)==kCCSuccess) return;
		[XADException raiseDecrunchException];
	}
#endif
	aes_cbc_decrypt(bytes,bytes,length,block,&aes);
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	uint8_t *bytebuffer=buffer;
	int bufferpos=streampos&15;
	int bufferlength=(-streampos)&15;
	int total=0;

	if(num<=bufferlength)
	{
		memcpy(&bytebuffer[total],&blockbuffer[bufferpos],num);
		return num;
	}

	memcpy(&bytebuffer[total],&blockbuffer[bufferpos],bufferlength);
	total+=bufferlength;

	int remaining=num-total;
	int remainingblocklength=remaining&~15;

	if(remainingblocklength)
	{
		int actual=[parent readAtMost:remainingblocklength toBuffer:&bytebuffer[total]];
		int actualblocklength=actual&~15;
		[self decryptCBC:&bytebuffer[total] length:actualblocklength];
		total+=actualblocklength;

		if(actualblocklength!=remainingblocklength)
		{
			[self endStream];
			return total;
		}
	}

	int endlength=num-total;
	if(endlength)
	{
		int actual=[parent readAtMost:16 toBuffer:blockbuffer];
		if(actual!=16)
		{
			[self endStream];
			return total;
		}

		[self decryptCBC:blockbuffer length:16];

		memcpy(&bytebuffer[total],&blockbuffer[0],endlength);
		total+=endlength;
	}

	return total;
}

@end
