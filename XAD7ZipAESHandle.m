/*
 * XAD7ZipAESHandle.m
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

#import "XAD7ZipAESHandle.h"

#import "Crypto/sha.h"
#import "XADException.h"

#ifdef __APPLE__
#import <CommonCrypto/CommonDigest.h>
#endif

@implementation XAD7ZipAESHandle

+(int)logRoundsForPropertyData:(NSData *)propertydata
{
	int length=[propertydata length];
	const uint8_t *bytes=[propertydata bytes];

	if(length<1) return -1;

	return bytes[0]&0x3f;
}

+(NSData *)saltForPropertyData:(NSData *)propertydata
{
	int length=[propertydata length];
	const uint8_t *bytes=[propertydata bytes];

	if(length<1) return nil;

	uint8_t flags=bytes[0];
	if(flags&0xc0)
	{
		if(length<2) return nil;

		if(flags&0x80)
		{
			int saltlength=(bytes[1]>>4)+1;
			if(length<2+saltlength) return nil;
			return [NSData dataWithBytes:&bytes[2] length:saltlength];
		}
	}

	return [NSData data];
}

+(NSData *)IVForPropertyData:(NSData *)propertydata
{
	int length=[propertydata length];
	const uint8_t *bytes=[propertydata bytes];

	if(length<1) return nil;

	uint8_t flags=bytes[0];
	if(flags&0xc0)
	{
		if(length<2) return nil;

		int saltlength=0;
		if(flags&0x80) saltlength=(bytes[1]>>4)+1;

		if(flags&0x40)
		{
			int ivlength=(bytes[1]&0x0f)+1;
			if(length<2+saltlength+ivlength) return nil;

			return [NSData dataWithBytes:&bytes[2+saltlength] length:ivlength];
		}
	}

	return [NSData data];
}

+(NSData *)keyForPassword:(NSString *)password salt:(NSData *)salt logRounds:(int)logrounds
{
	uint8_t key[32];

	int passchars=[password length];
	int passlength=passchars*2;
	uint8_t passbytes[passlength];
	for(int i=0;i<passchars;i++)
	{
		unichar c=[password characterAtIndex:i];
		passbytes[2*i]=c;
		passbytes[2*i+1]=c>>8;
	}

	int saltlength=[salt length];
	const uint8_t *saltbytes=[salt bytes];

	if(logrounds==0x3f)
	{
		int passcopylength=passlength;
		if(passcopylength+saltlength>sizeof(key)) passcopylength=sizeof(key)-saltlength;

		memset(key,0,sizeof(key));
		memcpy(&key[0],saltbytes,saltlength);
		memcpy(&key[saltlength],passbytes,passcopylength);
	}
	else
	{
		uint64_t numrounds=1LL<<logrounds;

#ifdef __APPLE__
		// [cooViewer] Hardware SHA-256 via CommonCrypto, fed in batches: the stream is
		// numrounds repetitions of (salt|password|64-bit round counter), so records are
		// pre-filled into a scratch buffer and only the counter bytes are patched per
		// round. Batching keeps the per-call overhead negligible; the digest is
		// bit-identical to the reference loop below (same byte stream).
		CC_SHA256_CTX sha;
		CC_SHA256_Init(&sha);

		int recordlength=saltlength+passlength+8;
		int batchrecords=16384/recordlength+1;
		uint8_t *batch=malloc((size_t)batchrecords*recordlength);
		if(!batch) [XADException raiseOutOfMemoryException];
		for(int r=0;r<batchrecords;r++)
		{
			memcpy(&batch[(size_t)r*recordlength],saltbytes,saltlength);
			memcpy(&batch[(size_t)r*recordlength+saltlength],passbytes,passlength);
		}

		uint64_t done=0;
		while(done<numrounds)
		{
			int n=numrounds-done>(uint64_t)batchrecords?batchrecords:(int)(numrounds-done);
			for(int r=0;r<n;r++)
			{
				uint64_t i=done+r;
				uint8_t *counter=&batch[(size_t)r*recordlength+saltlength+passlength];
				counter[0]=i&0xff; counter[1]=(i>>8)&0xff;
				counter[2]=(i>>16)&0xff; counter[3]=(i>>24)&0xff;
				counter[4]=(i>>32)&0xff; counter[5]=(i>>40)&0xff;
				counter[6]=(i>>48)&0xff; counter[7]=(i>>56)&0xff;
			}
			CC_SHA256_Update(&sha,batch,(CC_LONG)((size_t)n*recordlength));
			done+=n;
		}

		CC_SHA256_Final(key,&sha);
		free(batch);
#else
		SHA_CTX sha;
		SHA256_Init(&sha);

		for(uint64_t i=0;i<numrounds;i++)
		{
			SHA256_Update(&sha,saltbytes,saltlength);
			SHA256_Update(&sha,passbytes,passlength);
			SHA256_Update(&sha,(uint8_t[8]) {
				i&0xff,(i>>8)&0xff,(i>>16)&0xff,(i>>24)&0xff,
				(i>>32)&0xff,(i>>40)&0xff,(i>>48)&0xff,(i>>56)&0xff,
			},8);
		}

		SHA256_Final(key,&sha);
#endif
	}

	return [NSData dataWithBytes:key length:sizeof(key)];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length key:(NSData *)keydata IV:(NSData *)ivdata
{
	if(self=[super initWithParentHandle:handle length:length])
	{
		startoffs=[handle offsetInFile];

		int ivlength=[ivdata length];
		const uint8_t *ivbytes=[ivdata bytes];
		memset(iv,0,sizeof(iv));
		memcpy(iv,ivbytes,ivlength);

		const uint8_t *keybytes=[keydata bytes];
#ifdef __APPLE__
		// [cooViewer] Hardware AES via CommonCrypto: same AES-256-CBC, no padding,
		// same chaining semantics (CCCryptorReset restores the IV on stream reset).
		cryptor=NULL;
		if(CCCryptorCreateWithMode(kCCDecrypt,kCCModeCBC,kCCAlgorithmAES,ccNoPadding,
		iv,keybytes,32,NULL,0,0,0,&cryptor)!=kCCSuccess) cryptor=NULL;
		if(!cryptor) aes_decrypt_key256(keybytes,&aes); // fallback: vendored AES
#else
		aes_decrypt_key256(keybytes,&aes);
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

-(void)resetBlockStream
{
	[parent seekToFileOffset:startoffs];
	[self setBlockPointer:buffer];
	memcpy(block,iv,sizeof(iv));
#ifdef __APPLE__
	if(cryptor) CCCryptorReset(cryptor,iv);
#endif
}

-(int)produceBlockAtOffset:(off_t)pos
{
	int actual=[parent readAtMost:sizeof(buffer) toBuffer:buffer];
	if(actual==0) return -1;

#ifdef __APPLE__
	if(cryptor)
	{
		size_t moved=0;
		if(CCCryptorUpdate(cryptor,buffer,actual&~15,buffer,sizeof(buffer),&moved)==kCCSuccess)
		return actual;
		// fall through to the vendored implementation only if CommonCrypto failed
		// outright (should not happen); the chain state is then undefined, so raise.
		[XADException raiseDecrunchException];
	}
#endif
	aes_cbc_decrypt(buffer,buffer,actual&~15,block,&aes);

	return actual;
}

@end
